program WipRuntime;

{$APPTYPE CONSOLE}

{$R *.res}

uses
  System.Classes,
  System.SysUtils,
  System.IOUtils,
  System.NetEncoding,
  System.Hash,
  Wip.Safety,
  Winapi.Windows,
  Wip.Project in '..\Shared\Wip.Project.pas',
  Wip.InstallEngine in '..\Shared\Wip.InstallEngine.pas';

procedure PrintUsage;
begin
  Writeln('Package Studio Pro Runtime');
  Writeln('Usage: WipRuntime [embedded-manifest.json] [--install|--repair|--verify|--uninstall]');
  Writeln('If no project is supplied, embedded-manifest.json is loaded beside this executable.');
  Writeln('Default mode is dry-run.');
end;

procedure FinishSelfUninstall(RemoveSupportFolder, RemoveTargetFolder: Boolean);
var ExePath, SupportFolder, TargetFolder, Script, CommandLine: string;
  Startup: TStartupInfo; ProcessInfo: TProcessInformation;
  CleanupFolders: string;
begin
  ExePath := TPath.GetFullPath(ParamStr(0));
  SupportFolder := ExcludeTrailingPathDelimiter(ExtractFilePath(ExePath));
  if not SameText(ExtractFileName(SupportFolder), '.package-studio') then Exit;
  TargetFolder := ExcludeTrailingPathDelimiter(ExtractFilePath(SupportFolder));
  // The worker deletes this exact executable and empty directories only. It
  // never recursively deletes user files, and waits for our process to exit.
  CleanupFolders := '';
  if RemoveSupportFolder then CleanupFolders := '''' + SupportFolder.Replace('''''', '''''''''') + '''';
  if RemoveTargetFolder then begin
    if CleanupFolders <> '' then CleanupFolders := CleanupFolders + ',';
    CleanupFolders := CleanupFolders + '''' + TargetFolder.Replace('''''', '''''''''') + '''';
  end;
  Script := '$ErrorActionPreference=''Stop''; ' +
    '$p=Get-Process -Id ' + GetCurrentProcessId.ToString + ' -ErrorAction SilentlyContinue; ' +
    'if($p){$p.WaitForExit()}; ' +
    'Remove-Item -LiteralPath ''' + ExePath.Replace('''''', '''''''''') + ''' -Force; ' +
    'foreach($d in @(' + CleanupFolders + ')){if((Test-Path -LiteralPath $d) -and -not (Get-ChildItem -LiteralPath $d -Force | Select-Object -First 1)){Remove-Item -LiteralPath $d}}';
  CommandLine := 'powershell.exe -NoLogo -NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand ' +
    TNetEncoding.Base64.EncodeBytesToString(TEncoding.Unicode.GetBytes(Script));
  UniqueString(CommandLine);
  FillChar(Startup, SizeOf(Startup), 0); Startup.cb := SizeOf(Startup);
  FillChar(ProcessInfo, SizeOf(ProcessInfo), 0);
  if not CreateProcess(PChar(TPath.Combine(GetEnvironmentVariable('WINDIR'), 'System32\WindowsPowerShell\v1.0\powershell.exe')),
    PChar(CommandLine), nil, nil, False, CREATE_NO_WINDOW, nil, nil, Startup, ProcessInfo) then RaiseLastOSError;
  CloseHandle(ProcessInfo.hThread); CloseHandle(ProcessInfo.hProcess);
end;

var
  Project: TWipProject;
  Engine: TWipInstallEngine;
  Log: TStringList;
  Mode: TWipInstallMode;
  ProjectFile: string;
  I: Integer;
  UninstallJournal: TStringList;
  SelfStream: TFileStream;
  InstallRoot, SelfHash, ManifestPath: string;
  SelfCleanup, RemoveSupport, RemoveTarget: Boolean;
begin
  try
    ProjectFile := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'embedded-manifest.json';
    Mode := imDryRun;
    for I := 1 to ParamCount do
      if SameText(ParamStr(I), '--install') then
        Mode := imInstall
      else if SameText(ParamStr(I), '--repair') then
        Mode := imRepair
      else if SameText(ParamStr(I), '--verify') then
        Mode := imVerify
      else if SameText(ParamStr(I), '--uninstall') then
        Mode := imUninstall
      else if SameText(ParamStr(I), '--help') or SameText(ParamStr(I), '/?') then
      begin
        PrintUsage;
        ExitCode := 0;
        Exit;
      end
      else
        ProjectFile := ParamStr(I);

    if not FileExists(ProjectFile) then
      raise EFileNotFoundException.Create('Embedded manifest not found: ' + ProjectFile);

    Project := TWipProject.Create;
    Log := TStringList.Create;
    try
      Project.LoadFromFile(ProjectFile);
      Engine := TWipInstallEngine.Create(Log, ExtractFilePath(ProjectFile));
      try
        try
          SelfCleanup := False; RemoveSupport := False; RemoveTarget := False;
          if Mode = imUninstall then begin
            InstallRoot := TWipSafety.ExpandInstallFolder(Project.InstallFolder);
            ManifestPath := TPath.Combine(InstallRoot, 'PackageStudioPro.install-manifest');
            if TFile.Exists(ManifestPath) then begin
              UninstallJournal := TStringList.Create;
              try
                UninstallJournal.LoadFromFile(ManifestPath, TEncoding.UTF8);
                SelfStream := TFileStream.Create(ParamStr(0), fmOpenRead or fmShareDenyNone);
                try SelfHash := THashSHA2.GetHashString(SelfStream); finally SelfStream.Free end;
                SelfCleanup := UninstallJournal.IndexOf('file=' + ParamStr(0) + '|' + SelfHash) >= 0;
                RemoveSupport := UninstallJournal.IndexOf('folder=' + ExcludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)))) >= 0;
                RemoveTarget := UninstallJournal.IndexOf('folder=' + ExcludeTrailingPathDelimiter(InstallRoot)) >= 0;
              finally UninstallJournal.Free end;
            end;
          end;
          Engine.Execute(Project, Mode);
          if SelfCleanup then FinishSelfUninstall(RemoveSupport, RemoveTarget);
        finally
          for I := 0 to Log.Count - 1 do
            Writeln(Log[I]);
        end;
      finally
        Engine.Free;
      end;
    finally
      Log.Free;
      Project.Free;
    end;
  except
    on E: Exception do
    begin
      Writeln('ERROR: ' + E.ClassName + ': ' + E.Message);
      ExitCode := 1;
    end;
  end;
end.

