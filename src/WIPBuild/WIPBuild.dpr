program WIPBuild;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.Classes,
  System.IOUtils,
  System.SysUtils,
  System.Zip,
  Winapi.Windows,
  Wip.Project in '..\Shared\Wip.Project.pas',
  Wip.Safety in '..\Shared\Wip.Safety.pas';

function SafeFileName(const AValue: string): string;
var
  Ch: Char;
begin
  Result := Trim(AValue);
  for Ch in TPath.GetInvalidFileNameChars do
    Result := StringReplace(Result, Ch, '_', [rfReplaceAll]);
  if Result = '' then
    Result := 'Product';
end;

function SetupFileNameToken(const AValue: string): string;
begin
  Result := StringReplace(SafeFileName(AValue), ' ', '', [rfReplaceAll]);
  if Result = '' then
    Result := 'Product';
end;

procedure PrintUsage;
begin
  Writeln('Package Studio Pro Build Tool');
  Writeln('Usage: WIPBuild <project.wiproj> [output-folder]');
  Writeln;
  Writeln('No arguments: builds the bundled sample project to bin\ExportBuild and waits.');
end;

procedure WaitWhenInteractive(const AEnabled: Boolean);
begin
  if AEnabled then
  begin
    Writeln;
    Writeln('Press Enter to close this window.');
    Readln;
  end;
end;

procedure RunProcessChecked(const ACommandLine: string);
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  ExitCodeValue: Cardinal;
  MutableCommand: string;
begin
  MutableCommand := ACommandLine;
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));
  if not CreateProcess(nil, PChar(MutableCommand), nil, nil, False, CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
    raise EOSError.CreateFmt('Unable to start process. Windows error %d. Command: %s', [GetLastError, ACommandLine]);
  try
    if WaitForSingleObject(ProcessInfo.hProcess, 120000) <> WAIT_OBJECT_0 then begin
      TerminateProcess(ProcessInfo.hProcess, 1);
      WaitForSingleObject(ProcessInfo.hProcess, 5000);
      raise EExternalException.Create('Signing process timed out.');
    end;
    if not GetExitCodeProcess(ProcessInfo.hProcess, ExitCodeValue) then
      raise EOSError.CreateFmt('Unable to read process exit code. Windows error %d.', [GetLastError]);
    if ExitCodeValue <> 0 then
      raise EExternalException.CreateFmt('Process failed with exit code %d: %s', [ExitCodeValue, ACommandLine]);
  finally
    CloseHandle(ProcessInfo.hThread);
    CloseHandle(ProcessInfo.hProcess);
  end;
end;

function NormalizeArchiveName(const ARelativeName: string): string;
begin
  Result := StringReplace(ARelativeName, '\', '/', [rfReplaceAll]);
end;

procedure AppendFileToStream(const AFileName: string; ADestination: TStream);
var
  Source: TFileStream;
begin
  Source := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    ADestination.CopyFrom(Source, Source.Size);
  finally
    Source.Free;
  end;
end;

function RelativePayloadName(const ACommonRoot, ASourceFile: string): string;
var
  FullRoot: string;
  FullSource: string;
begin
  FullRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(ACommonRoot));
  FullSource := TPath.GetFullPath(ASourceFile);
  if FullSource.StartsWith(FullRoot, True) then
    Result := Copy(FullSource, Length(FullRoot) + 1, MaxInt)
  else
    Result := ExtractFileName(FullSource);
  Result := StringReplace(Result, '/', '\', [rfReplaceAll]);
  if (Result = '') or Result.Contains('..') or TPath.IsPathRooted(Result) then
    Result := ExtractFileName(FullSource);
end;

function CommonPayloadRoot(AProject: TWipProject): string;
var
  I: Integer;
  Candidate: string;
  SourceFolder: string;
begin
  Result := '';
  for I := 0 to AProject.Files.Count - 1 do
  begin
    SourceFolder := IncludeTrailingPathDelimiter(ExtractFilePath(TPath.GetFullPath(AProject.Files[I])));
    if Result = '' then
      Result := SourceFolder
    else
    begin
      Candidate := Result;
      while (Candidate <> '') and not SourceFolder.StartsWith(Candidate, True) do
      begin
        Candidate := ExcludeTrailingPathDelimiter(Candidate);
        Candidate := IncludeTrailingPathDelimiter(ExtractFilePath(Candidate));
        if SameText(Candidate, IncludeTrailingPathDelimiter(TPath.GetPathRoot(Candidate))) then
          Break;
      end;
      Result := Candidate;
    end;
  end;
  if Result = '' then
    Result := IncludeTrailingPathDelimiter(ExtractFilePath(TPath.GetFullPath(ParamStr(0))));
end;

procedure EnsureCleanOutputFolder(const AOutputFolder: string);
var
  FullOutput: string;
  MarkerFile: string;
  HasGeneratedContent: Boolean;
  FileName: string;
  DirName: string;
begin
  FullOutput := IncludeTrailingPathDelimiter(TPath.GetFullPath(AOutputFolder));
  if SameText(FullOutput, IncludeTrailingPathDelimiter(TPath.GetPathRoot(FullOutput))) then
    raise EInvalidOperation.Create('Output folder cannot be a drive root: ' + FullOutput);
  if TWipSafety.IsProtectedInstallFolder(FullOutput) then
    raise EInvalidOperation.Create('Output folder is protected and blocked: ' + FullOutput);

  ForceDirectories(FullOutput);
  MarkerFile := FullOutput + 'PackageStudioPro.output-folder.marker';
  HasGeneratedContent := TFile.Exists(MarkerFile) or TFile.Exists(FullOutput + 'embedded-manifest.json') or
    TFile.Exists(FullOutput + 'build-report.txt') or TDirectory.Exists(FullOutput + 'payload');

  if (not HasGeneratedContent) and
    ((Length(TDirectory.GetFiles(FullOutput)) > 0) or (Length(TDirectory.GetDirectories(FullOutput)) > 0)) then
    raise EInvalidOperation.Create('Output folder is not empty and is not marked as a Package Studio Pro build folder: ' + FullOutput);

  if HasGeneratedContent then
  begin
    for FileName in TDirectory.GetFiles(FullOutput) do
      TFile.Delete(FileName);
    for DirName in TDirectory.GetDirectories(FullOutput) do
      TDirectory.Delete(DirName, True);
  end;
  TFile.WriteAllText(MarkerFile, 'Package Studio Pro generated output folder', TEncoding.UTF8);
end;

procedure SignPackage(AProject: TWipProject; const APackageFile: string);
var
  CommandLine: string;
begin
  if not AProject.SigningEnabled then
    Exit;

  if Trim(AProject.SignToolPath) = '' then
    raise EInvalidOperation.Create('Signing is enabled but SignTool path is blank.');
  if not TFile.Exists(AProject.SigningCertificatePath) then
    raise EFileNotFoundException.Create('Signing certificate not found: ' + AProject.SigningCertificatePath);

  CommandLine := '"' + AProject.SignToolPath + '" sign /fd SHA256 /f "' +
    AProject.SigningCertificatePath + '"';
  if Trim(AProject.TimestampUrl) <> '' then
    CommandLine := CommandLine + ' /tr "' + AProject.TimestampUrl + '" /td SHA256';
  CommandLine := CommandLine + ' "' + APackageFile + '"';
  RunProcessChecked(CommandLine);
end;

procedure AddFolderToZip(AZip: TZipFile; const ABaseFolder, AFolder, AArchiveFile: string);
var
  FileName: string;
  Dir: string;
  RelativeName: string;
begin
  for FileName in TDirectory.GetFiles(AFolder) do
  begin
    if SameText(FileName, AArchiveFile) then
      Continue;
    if SameText(ExtractFileName(FileName), 'PackageStudioPro.output-folder.marker') then
      Continue;
    RelativeName := FileName;
    if RelativeName.StartsWith(ABaseFolder, True) then
      RelativeName := Copy(RelativeName, Length(ABaseFolder) + 1, MaxInt);
    AZip.Add(FileName, NormalizeArchiveName(RelativeName));
  end;
  for Dir in TDirectory.GetDirectories(AFolder) do
    AddFolderToZip(AZip, ABaseFolder, Dir, AArchiveFile);
end;

procedure CreateExportArchive(const AOutputFolder, AProductName: string; out AArchiveFile: string);
var
  Zip: TZipFile;
begin
  AArchiveFile := IncludeTrailingPathDelimiter(AOutputFolder) + SafeFileName(AProductName) + ' Export.zip';
  if TFile.Exists(AArchiveFile) then
    TFile.Delete(AArchiveFile);

  Zip := TZipFile.Create;
  try
    Zip.Open(AArchiveFile, zmWrite);
    AddFolderToZip(Zip, IncludeTrailingPathDelimiter(AOutputFolder), AOutputFolder, AArchiveFile);
  finally
    Zip.Free;
  end;
end;

procedure CreateSetupBundle(const AOutputFolder, ABundleFile: string);
var
  Zip: TZipFile;
  BaseFolder: string;
begin
  if TFile.Exists(ABundleFile) then
    TFile.Delete(ABundleFile);
  BaseFolder := IncludeTrailingPathDelimiter(AOutputFolder);
  Zip := TZipFile.Create;
  try
    Zip.Open(ABundleFile, zmWrite);
    Zip.Add(BaseFolder + 'embedded-manifest.json', 'install.wiproj');
    if not TFile.Exists(BaseFolder + 'WipRuntime.exe') then
      raise EFileNotFoundException.Create('WipRuntime.exe is required for a durable uninstaller.');
    Zip.Add(BaseFolder + 'WipRuntime.exe', 'WipRuntime.exe');
    if TDirectory.Exists(BaseFolder + 'payload') then
      AddFolderToZip(Zip, BaseFolder, BaseFolder + 'payload', ABundleFile);
  finally
    Zip.Free;
  end;
end;

procedure SetSetupPrivileges(AProject: TWipProject; const ASetupFile: string);
var ModuleHandle, UpdateHandle: THandle; Resource: HRSRC; Data: HGLOBAL;
  ManifestText, Target, UserRoot: string; Bytes: TBytes; Language: Word;
begin
  ModuleHandle := LoadLibraryEx(PChar(ASetupFile), 0, LOAD_LIBRARY_AS_DATAFILE);
  if ModuleHandle = 0 then RaiseLastOSError;
  try
    Resource := FindResource(ModuleHandle, MAKEINTRESOURCE(1), MAKEINTRESOURCE(24));
    if Resource = 0 then RaiseLastOSError;
    Data := LoadResource(ModuleHandle, Resource);
    SetLength(Bytes, SizeofResource(ModuleHandle, Resource));
    Move(PByte(LockResource(Data))^, Bytes[0], Length(Bytes));
    ManifestText := TEncoding.UTF8.GetString(Bytes);
  finally FreeLibrary(ModuleHandle) end;
  Target := IncludeTrailingPathDelimiter(TWipSafety.ExpandInstallFolder(AProject.InstallFolder));
  UserRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(GetEnvironmentVariable('USERPROFILE')));
  if Target.StartsWith(UserRoot, True) then
    ManifestText := ManifestText.Replace('level="requireAdministrator"', 'level="asInvoker"')
  else ManifestText := ManifestText.Replace('level="asInvoker"', 'level="requireAdministrator"');
  Bytes := TEncoding.UTF8.GetBytes(ManifestText);
  UpdateHandle := BeginUpdateResource(PChar(ASetupFile), False);
  if UpdateHandle = 0 then RaiseLastOSError;
  try
    for Language in TArray<Word>.Create(0, 1033) do
      if not UpdateResource(UpdateHandle, MAKEINTRESOURCE(24), MAKEINTRESOURCE(1), Language, @Bytes[0], Length(Bytes)) then RaiseLastOSError;
    if not EndUpdateResource(UpdateHandle, False) then RaiseLastOSError;
    UpdateHandle := 0;
  finally if UpdateHandle <> 0 then EndUpdateResource(UpdateHandle, True) end;
end;

procedure EmbedSetupBundle(const ASetupFile, ABundleFile: string);
const
  EmbeddedPackageMarker = 'PSPSETUPBUNDLE1';
var
  SetupStream: TFileStream;
  BundleSize: Int64;
  MarkerBytes: TBytes;
begin
  BundleSize := TFile.GetSize(ABundleFile);
  MarkerBytes := TEncoding.ASCII.GetBytes(EmbeddedPackageMarker);
  SetupStream := TFileStream.Create(ASetupFile, fmOpenReadWrite or fmShareDenyWrite);
  try
    SetupStream.Position := SetupStream.Size;
    AppendFileToStream(ABundleFile, SetupStream);
    SetupStream.WriteBuffer(BundleSize, SizeOf(BundleSize));
    SetupStream.WriteBuffer(MarkerBytes[0], Length(MarkerBytes));
  finally
    SetupStream.Free;
  end;
end;

procedure WriteSafetyReport(AProject: TWipProject; const AOutputFolder: string);
var
  Report: TStringList;
begin
  Report := TStringList.Create;
  try
    Report.Add('Package Studio Pro safety report');
    Report.Add('Status: PASSED');
    Report.Add('Product: ' + AProject.ProductName);
    Report.Add('Install folder: ' + TWipSafety.ExpandInstallFolder(AProject.InstallFolder));
    Report.Add('Protected folder guard: enabled');
    Report.Add('Registry scope guard: HKCU only');
    Report.Add('PATH guard: append-only HKCU Path entries with manifest cleanup');
    Report.Add('Rollback: enabled');
    Report.Add('Uninstall manifest: enabled');
    Report.Add('File hash protection: enabled');
    Report.Add('Modified-file preservation: enabled');
    Report.Add('Pre-existing file restore: enabled');
    Report.Add('Uninstall registration scope: HKCU');
    if AProject.SigningEnabled then
      Report.Add('Signing: enabled')
    else
      Report.Add('Signing: disabled');
    Report.SaveToFile(IncludeTrailingPathDelimiter(AOutputFolder) + 'safety-report.txt', TEncoding.UTF8);
  finally
    Report.Free;
  end;
end;

var
  Project: TWipProject;
  ProjectFile: string;
  OutputFolder: string;
  RuntimeSource: string;
  RuntimeTarget: string;
  ConsoleRuntimeSource: string;
  ConsoleRuntimeTarget: string;
  PayloadTarget: string;
  PayloadFolder: string;
  SourceFile: string;
  StagedFile: string;
  Report: TStringList;
  PackagedProject: TWipProject;
  SafetyErrors: TStringList;
  ArchiveFile: string;
  BundleFile: string;
  I: Integer;
  InteractiveMode: Boolean;
begin
  InteractiveMode := ParamCount < 1;
  try
    if InteractiveMode then
    begin
      PrintUsage;
      ProjectFile := TPath.GetFullPath(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + '..\samples\HelloProduct.wiproj');
      OutputFolder := TPath.GetFullPath(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'ExportBuild');
      Writeln;
      Writeln('Double-click build mode');
      Writeln('Project: ' + ProjectFile);
      Writeln('Output: ' + OutputFolder);
      Writeln;
    end
    else
    begin
      ProjectFile := ParamStr(1);
      if ParamCount >= 2 then
        OutputFolder := ParamStr(2)
      else
        OutputFolder := IncludeTrailingPathDelimiter(ExtractFilePath(ProjectFile)) + 'Output';
    end;

    Project := TWipProject.Create;
    try
      Project.LoadFromFile(ProjectFile);
      SafetyErrors := TStringList.Create;
      try
        if not TWipSafety.ValidateProject(Project, SafetyErrors) then
        begin
          Writeln('ERROR: Project failed safety validation.');
          Writeln(SafetyErrors.Text);
          ExitCode := 1;
          WaitWhenInteractive(InteractiveMode);
          Exit;
        end;
      finally
        SafetyErrors.Free;
      end;

      OutputFolder := TPath.GetFullPath(OutputFolder);
      EnsureCleanOutputFolder(OutputFolder);
      RuntimeSource := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'WipSetup.exe';
      if not TFile.Exists(RuntimeSource) then
        raise EFileNotFoundException.Create('WipSetup.exe is required for a self-contained installer. Rebuild Package Studio Pro first.');
      RuntimeTarget := IncludeTrailingPathDelimiter(OutputFolder) + SetupFileNameToken(Project.ProductName) + 'Setup.exe';
      ConsoleRuntimeSource := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'WipRuntime.exe';
      ConsoleRuntimeTarget := IncludeTrailingPathDelimiter(OutputFolder) + 'WipRuntime.exe';
      PayloadTarget := IncludeTrailingPathDelimiter(OutputFolder) + 'embedded-manifest.json';
      PayloadFolder := IncludeTrailingPathDelimiter(OutputFolder) + 'payload';

      if not TFile.Exists(RuntimeSource) then
        raise EFileNotFoundException.Create('Runtime executable not found. Expected WipSetup.exe or WipRuntime.exe beside WIPBuild.exe.');

      for I := 0 to Project.Files.Count - 1 do
        if not TFile.Exists(Project.Files[I]) then
          raise EFileNotFoundException.Create('Payload file not found: ' + Project.Files[I]);

      TFile.Copy(RuntimeSource, RuntimeTarget, True);
      if TFile.Exists(ConsoleRuntimeSource) then
        TFile.Copy(ConsoleRuntimeSource, ConsoleRuntimeTarget, True);
      ForceDirectories(PayloadFolder);

      PackagedProject := TWipProject.Create;
      try
        PackagedProject.ProductName := Project.ProductName;
        PackagedProject.Publisher := Project.Publisher;
        PackagedProject.Version := Project.Version;
        PackagedProject.InstallFolder := Project.InstallFolder;
        PackagedProject.LicenseText := Project.LicenseText;
        PackagedProject.SigningEnabled := False;
        PackagedProject.SignToolPath := '';
        PackagedProject.SigningCertificatePath := '';
        PackagedProject.TimestampUrl := Project.TimestampUrl;
        PackagedProject.Shortcuts.Assign(Project.Shortcuts);
        PackagedProject.RegistryEntries.Assign(Project.RegistryEntries);
        PackagedProject.EnvironmentVariables.Assign(Project.EnvironmentVariables);
        PackagedProject.PathEntries.Assign(Project.PathEntries);
        PackagedProject.FileAssociations.Assign(Project.FileAssociations);
        PackagedProject.Prerequisites.Assign(Project.Prerequisites);
        PackagedProject.Features.Assign(Project.Features);

        PayloadFolder := IncludeTrailingPathDelimiter(PayloadFolder);
        SourceFile := CommonPayloadRoot(Project);
        for I := 0 to Project.Files.Count - 1 do
        begin
          StagedFile := RelativePayloadName(SourceFile, Project.Files[I]);
          ForceDirectories(ExtractFilePath(PayloadFolder + StagedFile));
          TFile.Copy(Project.Files[I], PayloadFolder + StagedFile, True);
          PackagedProject.Files.Add('payload\' + StagedFile);
        end;

        PackagedProject.SaveToFile(PayloadTarget);
      finally
        PackagedProject.Free;
      end;

      BundleFile := IncludeTrailingPathDelimiter(OutputFolder) + 'setup-bundle.zip';
      SetSetupPrivileges(Project, RuntimeTarget);
      SetSetupPrivileges(Project, ConsoleRuntimeTarget);
      CreateSetupBundle(OutputFolder, BundleFile);
      EmbedSetupBundle(RuntimeTarget, BundleFile);
      TFile.Delete(BundleFile);
      SignPackage(Project, RuntimeTarget);

      Report := TStringList.Create;
      try
        Report.Add('Package Studio Pro build report');
        Report.Add('Product: ' + Project.ProductName);
        Report.Add('Version: ' + Project.Version);
        Report.Add('Publisher: ' + Project.Publisher);
        Report.Add('Install folder: ' + Project.InstallFolder);
        Report.Add('Files: ' + Project.Files.Count.ToString);
        Report.Add('Shortcuts: ' + Project.Shortcuts.Count.ToString);
        Report.Add('Registry entries: ' + Project.RegistryEntries.Count.ToString);
        Report.Add('Environment variables: ' + Project.EnvironmentVariables.Count.ToString);
        Report.Add('PATH entries: ' + Project.PathEntries.Count.ToString);
        Report.Add('File associations: ' + Project.FileAssociations.Count.ToString);
        Report.Add('Prerequisites: ' + Project.Prerequisites.Count.ToString);
        Report.Add('Features: ' + Project.Features.Count.ToString);
        Report.Add('Runtime: ' + RuntimeTarget);
        if TFile.Exists(ConsoleRuntimeTarget) then
          Report.Add('Console runtime: ' + ConsoleRuntimeTarget);
        Report.Add('Setup EXE: self-contained');
        Report.Add('Embedded manifest: included inside setup EXE');
        Report.Add('Payload: included inside setup EXE');
        Report.SaveToFile(IncludeTrailingPathDelimiter(OutputFolder) + 'build-report.txt', TEncoding.UTF8);
      finally
        Report.Free;
      end;

      WriteSafetyReport(Project, OutputFolder);
      CreateExportArchive(OutputFolder, Project.ProductName, ArchiveFile);

      Writeln('Project: ' + Project.ProductName);
      Writeln('Version: ' + Project.Version);
      Writeln('Publisher: ' + Project.Publisher);
      Writeln('Install folder: ' + Project.InstallFolder);
      Writeln('Files: ' + Project.Files.Count.ToString);
      Writeln('Shortcuts: ' + Project.Shortcuts.Count.ToString);
      Writeln('Registry entries: ' + Project.RegistryEntries.Count.ToString);
      Writeln('Environment variables: ' + Project.EnvironmentVariables.Count.ToString);
      Writeln('PATH entries: ' + Project.PathEntries.Count.ToString);
      Writeln('File associations: ' + Project.FileAssociations.Count.ToString);
      Writeln('Prerequisites: ' + Project.Prerequisites.Count.ToString);
      Writeln('Features: ' + Project.Features.Count.ToString);
      Writeln('Output: ' + OutputFolder);
      Writeln('Runtime: ' + RuntimeTarget);
      Writeln('Setup EXE: self-contained');
      Writeln('Payload: included inside setup EXE');
      Writeln('Archive: ' + ArchiveFile);
      Writeln('Build completed.');
      WaitWhenInteractive(InteractiveMode);
    finally
      Project.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln('ERROR: ' + E.ClassName + ': ' + E.Message);
      ExitCode := 1;
      WaitWhenInteractive(InteractiveMode);
    end;
  end;
end.

