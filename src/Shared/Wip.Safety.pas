unit Wip.Safety;

interface

uses
  System.Classes, System.IOUtils, System.SysUtils, Wip.Project;

type
  TWipSafety = class
  public
    class function ExpandInstallFolder(const AFolder: string): string; static;
    class function IsProtectedInstallFolder(const AFolder: string): Boolean; static;
    class function ValidateProject(AProject: TWipProject; AErrors: TStrings): Boolean; static;
    class function ValidateRegistryEntry(const AEntry: string; out AMessage: string): Boolean; static;
  end;

implementation

class function TWipSafety.ExpandInstallFolder(const AFolder: string): string;
var
  ProgramFiles: string;
  LocalAppData: string;
begin
  ProgramFiles := GetEnvironmentVariable('ProgramFiles');
  LocalAppData := GetEnvironmentVariable('LOCALAPPDATA');
  Result := StringReplace(AFolder, '{pf}', ProgramFiles, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{localappdata}', LocalAppData, [rfReplaceAll, rfIgnoreCase]);
  Result := TPath.GetFullPath(Result);
end;

class function TWipSafety.IsProtectedInstallFolder(const AFolder: string): Boolean;
var
  FullFolder: string;
  WindowsFolder: string;
  SystemFolder: string;
  Root: string;
begin
  FullFolder := IncludeTrailingPathDelimiter(UpperCase(TPath.GetFullPath(AFolder)));
  WindowsFolder := IncludeTrailingPathDelimiter(UpperCase(GetEnvironmentVariable('WINDIR')));
  SystemFolder := IncludeTrailingPathDelimiter(UpperCase(TPath.Combine(GetEnvironmentVariable('WINDIR'), 'System32')));
  Root := IncludeTrailingPathDelimiter(UpperCase(TPath.GetPathRoot(FullFolder)));

  Result := (FullFolder = Root) or
    FullFolder.StartsWith(WindowsFolder) or
    FullFolder.StartsWith(SystemFolder);
end;

class function TWipSafety.ValidateRegistryEntry(const AEntry: string; out AMessage: string): Boolean;
var
  KeyName: string;
  ValueName: string;
  FirstSep: Integer;
  SecondSep: Integer;
begin
  Result := False;
  AMessage := '';
  FirstSep := Pos('|', AEntry);
  SecondSep := Pos('|', Copy(AEntry, FirstSep + 1, MaxInt));
  if (FirstSep <= 0) or (SecondSep <= 0) then
  begin
    AMessage := 'Registry entry must use Key|Name|Value: ' + AEntry;
    Exit;
  end;
  Inc(SecondSep, FirstSep);

  KeyName := Copy(AEntry, 1, FirstSep - 1);
  ValueName := Copy(AEntry, FirstSep + 1, SecondSep - FirstSep - 1);

  if not KeyName.StartsWith('HKCU\', True) then
  begin
    AMessage := 'Only HKCU registry entries are allowed without elevation: ' + KeyName;
    Exit;
  end;

  if SameText(KeyName, 'HKCU\') then
  begin
    AMessage := 'Registry entry cannot target HKCU root.';
    Exit;
  end;

  if Trim(ValueName) = '' then
  begin
    AMessage := 'Registry value name cannot be blank: ' + AEntry;
    Exit;
  end;

  Result := True;
end;

class function TWipSafety.ValidateProject(AProject: TWipProject; AErrors: TStrings): Boolean;
var
  I: Integer;
  Sep: Integer;
  SecondSep: Integer;
  MessageText: string;
  TargetFolder: string;
  TargetNames: TStringList;
  TargetName: string;
  EntryText: string;
  NameText: string;
  ValueText: string;
  DescriptionText: string;
  TargetText: string;
  function CommonPayloadRoot: string;
  var
    N: Integer;
    Candidate: string;
    SourceFolder: string;
  begin
    Result := '';
    for N := 0 to AProject.Files.Count - 1 do
    begin
      SourceFolder := IncludeTrailingPathDelimiter(ExtractFilePath(TPath.GetFullPath(AProject.Files[N])));
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
  end;
  function RelativePayloadName(const ACommonRoot, ASourceFile: string): string;
  var
    FullRoot: string;
    FullSource: string;
  begin
    FullRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(ACommonRoot));
    FullSource := TPath.GetFullPath(ASourceFile);
    if (ACommonRoot <> '') and FullSource.StartsWith(FullRoot, True) then
      Result := Copy(FullSource, Length(FullRoot) + 1, MaxInt)
    else
      Result := ExtractFileName(FullSource);
    Result := StringReplace(Result, '/', '\', [rfReplaceAll]);
    if (Trim(Result) = '') or Result.Contains('..') or TPath.IsPathRooted(Result) then
      Result := ExtractFileName(FullSource);
  end;
begin
  AErrors.Clear;

  if Trim(AProject.ProductName) = '' then
    AErrors.Add('Product name is required.');
  if Trim(AProject.Version) = '' then
    AErrors.Add('Version is required.');
  if Trim(AProject.InstallFolder) = '' then
    AErrors.Add('Install folder is required.');

  if Trim(AProject.InstallFolder) <> '' then
  begin
    TargetFolder := ExpandInstallFolder(AProject.InstallFolder);
    if IsProtectedInstallFolder(TargetFolder) then
      AErrors.Add('Install folder is protected and blocked: ' + TargetFolder);
  end;

  TargetNames := TStringList.Create;
  try
    TargetNames.CaseSensitive := False;
    for I := 0 to AProject.Files.Count - 1 do
    begin
      if not TFile.Exists(AProject.Files[I]) then
        AErrors.Add('Payload file does not exist: ' + AProject.Files[I]);
      TargetName := RelativePayloadName(CommonPayloadRoot, AProject.Files[I]);
      if Trim(TargetName) = '' then
        AErrors.Add('Payload file has no target file name: ' + AProject.Files[I])
      else if TargetNames.IndexOf(TargetName) >= 0 then
        AErrors.Add('Payload files collide in the install folder tree: ' + TargetName)
      else
        TargetNames.Add(TargetName);
    end;
  finally
    TargetNames.Free;
  end;

  for I := 0 to AProject.Shortcuts.Count - 1 do
  begin
    EntryText := AProject.Shortcuts[I];
    Sep := Pos('|', EntryText);
    if Sep > 0 then
    begin
      NameText := Copy(EntryText, 1, Sep - 1);
      EntryText := Copy(EntryText, Sep + 1, MaxInt);
      if not (SameText(NameText, 'InstallFolder') or SameText(NameText, 'Desktop') or SameText(NameText, 'StartMenu')) then
        AErrors.Add('Shortcut location must be InstallFolder, Desktop, or StartMenu: ' + NameText);
    end;
    Sep := Pos('|', EntryText);
    if Sep <= 0 then
      AErrors.Add('Shortcut entry must use Location|Name|Target: ' + AProject.Shortcuts[I])
    else if (Trim(Copy(EntryText, 1, Sep - 1)) = '') or (Trim(Copy(EntryText, Sep + 1, MaxInt)) = '') then
      AErrors.Add('Shortcut name and target are required: ' + AProject.Shortcuts[I])
    else
    begin
      TargetText := Trim(Copy(EntryText, Sep + 1, MaxInt));
      if TPath.IsPathRooted(TargetText) and not TFile.Exists(TargetText) then
        AErrors.Add('Shortcut target does not exist: ' + TargetText);
    end;
  end;

  for I := 0 to AProject.RegistryEntries.Count - 1 do
    if not ValidateRegistryEntry(AProject.RegistryEntries[I], MessageText) then
      AErrors.Add(MessageText);

  for I := 0 to AProject.EnvironmentVariables.Count - 1 do
  begin
    EntryText := AProject.EnvironmentVariables[I];
    Sep := Pos('|', EntryText);
    if Sep <= 0 then
      AErrors.Add('Environment variable must use Name|Value: ' + EntryText)
    else
    begin
      NameText := Trim(Copy(EntryText, 1, Sep - 1));
      ValueText := Copy(EntryText, Sep + 1, MaxInt);
      if NameText = '' then
        AErrors.Add('Environment variable name cannot be blank.')
      else if NameText.Contains('=') then
        AErrors.Add('Environment variable name cannot contain "=": ' + NameText);
      if ValueText.Contains(#0) then
        AErrors.Add('Environment variable value cannot contain null characters: ' + NameText);
    end;
  end;

  for I := 0 to AProject.PathEntries.Count - 1 do
  begin
    EntryText := Trim(AProject.PathEntries[I]);
    if EntryText = '' then
      AErrors.Add('PATH entry cannot be blank.')
    else if EntryText.Contains(';') then
      AErrors.Add('PATH entry cannot contain semicolons: ' + EntryText)
    else if EntryText.Contains(#0) then
      AErrors.Add('PATH entry cannot contain null characters.');
  end;

  for I := 0 to AProject.FileAssociations.Count - 1 do
  begin
    EntryText := AProject.FileAssociations[I];
    Sep := Pos('|', EntryText);
    SecondSep := Pos('|', Copy(EntryText, Sep + 1, MaxInt));
    if (Sep <= 0) or (SecondSep <= 0) then
      AErrors.Add('File association must use Extension|Description|Target: ' + EntryText)
    else
    begin
      Inc(SecondSep, Sep);
      NameText := Trim(Copy(EntryText, 1, Sep - 1));
      DescriptionText := Trim(Copy(EntryText, Sep + 1, SecondSep - Sep - 1));
      TargetText := Trim(Copy(EntryText, SecondSep + 1, MaxInt));
      if NameText = '' then
        AErrors.Add('File association extension cannot be blank.')
      else if NameText.Contains('\') or NameText.Contains('/') or NameText.Contains('|') then
        AErrors.Add('File association extension contains invalid characters: ' + NameText);
      if DescriptionText = '' then
        AErrors.Add('File association description cannot be blank: ' + EntryText);
      if TargetText = '' then
        AErrors.Add('File association target cannot be blank: ' + EntryText)
      else if TPath.IsPathRooted(TargetText) and not TFile.Exists(TargetText) then
        AErrors.Add('File association target does not exist: ' + TargetText);
    end;
  end;

  if AProject.SigningEnabled then
  begin
    if Trim(AProject.SignToolPath) = '' then
      AErrors.Add('Signing is enabled but SignTool path is blank.');
    if Trim(AProject.SigningCertificatePath) = '' then
      AErrors.Add('Signing is enabled but certificate path is blank.')
    else if not TFile.Exists(AProject.SigningCertificatePath) then
      AErrors.Add('Signing certificate does not exist: ' + AProject.SigningCertificatePath);
  end;

  Result := AErrors.Count = 0;
end;

end.

