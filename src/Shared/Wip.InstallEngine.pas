unit Wip.InstallEngine;

interface

uses
  System.Classes, System.Hash, System.IOUtils, System.SysUtils, System.Win.ComObj, System.Win.Registry,
  Winapi.ActiveX, Winapi.ShlObj, Winapi.Windows, Wip.Project, Wip.Safety;

type
  TWipInstallMode = (imDryRun, imInstall, imRepair, imVerify, imUninstall);
  TWipInstallLogEvent = procedure(const AMessage: string) of object;

  TWipInstallEngine = class
  private
    FBaseFolder: string;
    FLog: TStrings;
    FOnLog: TWipInstallLogEvent;
    function ExpandInstallFolder(const AFolder: string): string;
    function ManifestFileName(const ATargetFolder: string): string;
    function FileHash(const AFileName: string): string;
    function ManifestFileEntry(const AFileName: string): string;
    function BackupFolderName(const ATargetFolder: string): string;
    function ShortcutFolderForLocation(const ALocation, ATargetFolder: string): string;
    function ShellFolderPath(const ACSIDL: Integer; const AFallback: string): string;
    function SafeFileName(const AValue: string): string;
    function EscapeManifestField(const AValue: string): string;
    function UnescapeManifestField(const AValue: string): string;
    function ResolveSourceFile(const ASourceFile: string): string;
    function TargetRelativeFileName(const ASourceFile: string): string;
    function ResolveTargetFile(const ATargetFolder, ASourceFile: string): string;
    procedure SplitManifestFields(const AValue: string; AFields: TStrings);
    procedure BackupExistingFile(const AFileName, ATargetFolder: string; AManifest: TStrings);
    procedure CreateShortcutFile(const ALinkFile, ATargetFile: string);
    procedure WriteRegistryEntry(const AEntry: string; AManifest: TStrings);
    procedure DeleteRegistryEntry(const AEntry: string);
    procedure WriteEnvironmentVariable(const AEntry: string; AManifest: TStrings);
    procedure DeleteEnvironmentVariable(const AName: string);
    function ResolvePathEntry(const AEntry, ATargetFolder: string): string;
    function PathContainsEntry(const APathValue, AEntry: string): Boolean;
    function RemovePathEntry(const APathValue, AEntry: string): string;
    procedure WritePathEntry(const AEntry, ATargetFolder: string; AManifest: TStrings);
    procedure DeletePathEntry(const AEntry: string);
    procedure WriteFileAssociation(const AEntry, ATargetFolder: string; AManifest: TStrings);
    procedure DeleteFileAssociation(const AEntry: string);
    function UninstallRegistryKeyName(AProject: TWipProject): string;
    procedure WriteUninstallRegistration(AProject: TWipProject; const ATargetFolder: string; AManifest: TStrings);
    procedure DeleteUninstallRegistration(const AKeyName: string);
    procedure EnsureOwnedDirectory(const AFolder, ATargetFolder: string; AManifest: TStrings);
    procedure CheckPrerequisites(AProject: TWipProject);
    procedure ValidateManagedPath(const AFileName, ATargetFolder: string);
    procedure RollbackManifest(AManifest: TStrings; const ATargetFolder: string);
    procedure Log(const AMessage: string);
    procedure ExecuteInstall(AProject: TWipProject; const ATargetFolder: string; AMode: TWipInstallMode);
    procedure ExecuteVerify(AProject: TWipProject; const ATargetFolder: string);
    procedure ExecuteUninstall(const ATargetFolder: string);
  public
    constructor Create(ALog: TStrings; const ABaseFolder: string = '');
    procedure Execute(AProject: TWipProject; AMode: TWipInstallMode);
    property OnLog: TWipInstallLogEvent read FOnLog write FOnLog;
  end;

implementation

constructor TWipInstallEngine.Create(ALog: TStrings; const ABaseFolder: string);
begin
  inherited Create;
  FLog := ALog;
  if ABaseFolder <> '' then
    FBaseFolder := IncludeTrailingPathDelimiter(TPath.GetFullPath(ABaseFolder))
  else
    FBaseFolder := IncludeTrailingPathDelimiter(TPath.GetFullPath(ExtractFilePath(ParamStr(0))));
end;

function TWipInstallEngine.ExpandInstallFolder(const AFolder: string): string;
begin
  Result := TWipSafety.ExpandInstallFolder(AFolder);
end;

function TWipInstallEngine.ResolveSourceFile(const ASourceFile: string): string;
begin
  if TPath.IsPathRooted(ASourceFile) then
    Result := ASourceFile
  else
    Result := FBaseFolder + ASourceFile;
end;

function TWipInstallEngine.TargetRelativeFileName(const ASourceFile: string): string;
begin
  Result := StringReplace(ASourceFile, '/', '\', [rfReplaceAll]);
  if TPath.IsPathRooted(Result) then
    Result := ExtractFileName(Result)
  else if Result.StartsWith('payload\', True) then
    Result := Copy(Result, Length('payload\') + 1, MaxInt);

  if (Trim(Result) = '') or Result.Contains('..') or TPath.IsPathRooted(Result) then
    Result := ExtractFileName(ASourceFile);
end;

function TWipInstallEngine.ResolveTargetFile(const ATargetFolder, ASourceFile: string): string;
var
  TargetRoot: string;
begin
  TargetRoot := IncludeTrailingPathDelimiter(TPath.GetFullPath(ATargetFolder));
  Result := TPath.GetFullPath(TargetRoot + TargetRelativeFileName(ASourceFile));
  if not Result.StartsWith(TargetRoot, True) then
    raise EInvalidOperation.Create('Payload target path escapes the install folder: ' + ASourceFile);
end;

function TWipInstallEngine.ManifestFileName(const ATargetFolder: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ATargetFolder) + 'PackageStudioPro.install-manifest';
end;

function TWipInstallEngine.FileHash(const AFileName: string): string;
var
  Stream: TFileStream;
begin
  Stream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := THashSHA2.GetHashString(Stream);
  finally
    Stream.Free;
  end;
end;

function TWipInstallEngine.ManifestFileEntry(const AFileName: string): string;
begin
  Result := 'file=' + AFileName + '|' + FileHash(AFileName);
end;

function TWipInstallEngine.BackupFolderName(const ATargetFolder: string): string;
begin
  Result := IncludeTrailingPathDelimiter(ATargetFolder) + '.wip-backup';
end;

function TWipInstallEngine.ShortcutFolderForLocation(const ALocation, ATargetFolder: string): string;
var
  LocationText: string;
  UserScope: Boolean;
begin
  UserScope := IncludeTrailingPathDelimiter(TPath.GetFullPath(ATargetFolder)).StartsWith(
    IncludeTrailingPathDelimiter(TPath.GetFullPath(GetEnvironmentVariable('USERPROFILE'))), True);
  if not UserScope then begin
    if SameText(ALocation, 'Desktop') then Exit(ShellFolderPath(CSIDL_COMMON_DESKTOPDIRECTORY,
      TPath.Combine(GetEnvironmentVariable('PUBLIC'), 'Desktop')));
    if SameText(ALocation, 'StartMenu') then Exit(ShellFolderPath(CSIDL_COMMON_PROGRAMS,
      TPath.Combine(GetEnvironmentVariable('ProgramData'), 'Microsoft\Windows\Start Menu\Programs')));
  end;
  LocationText := Trim(ALocation);
  if LocationText = '' then
    LocationText := 'InstallFolder';

  if SameText(LocationText, 'InstallFolder') then
    Result := IncludeTrailingPathDelimiter(ATargetFolder) + 'Shortcuts'
  else if SameText(LocationText, 'Desktop') then
    Result := ShellFolderPath(CSIDL_DESKTOPDIRECTORY,
      TPath.Combine(GetEnvironmentVariable('USERPROFILE'), 'Desktop'))
  else if SameText(LocationText, 'StartMenu') then
    Result := ShellFolderPath(CSIDL_PROGRAMS,
      TPath.Combine(GetEnvironmentVariable('APPDATA'), 'Microsoft\Windows\Start Menu\Programs'))
  else
    raise EInvalidOperation.Create('Unsupported shortcut location: ' + ALocation);
end;

function TWipInstallEngine.ShellFolderPath(const ACSIDL: Integer; const AFallback: string): string;
var
  Buffer: array[0..MAX_PATH] of Char;
begin
  FillChar(Buffer, SizeOf(Buffer), 0);
  if Succeeded(SHGetFolderPath(0, ACSIDL, 0, SHGFP_TYPE_CURRENT, Buffer)) and (Buffer[0] <> #0) then
    Result := Buffer
  else
    Result := AFallback;
end;

function TWipInstallEngine.SafeFileName(const AValue: string): string;
var
  Ch: Char;
begin
  Result := Trim(AValue);
  for Ch in TPath.GetInvalidFileNameChars do
    Result := StringReplace(Result, Ch, '_', [rfReplaceAll]);
  if Result = '' then
    Result := 'Shortcut';
end;

function TWipInstallEngine.EscapeManifestField(const AValue: string): string;
begin
  Result := StringReplace(AValue, '%', '%25', [rfReplaceAll]);
  Result := StringReplace(Result, '|', '%7C', [rfReplaceAll]);
  Result := StringReplace(Result, #13, '%0D', [rfReplaceAll]);
  Result := StringReplace(Result, #10, '%0A', [rfReplaceAll]);
end;

function TWipInstallEngine.UnescapeManifestField(const AValue: string): string;
begin
  Result := StringReplace(AValue, '%0A', #10, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '%0D', #13, [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '%7C', '|', [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '%25', '%', [rfReplaceAll, rfIgnoreCase]);
end;

procedure TWipInstallEngine.SplitManifestFields(const AValue: string; AFields: TStrings);
begin
  AFields.Clear;
  AFields.StrictDelimiter := True;
  AFields.Delimiter := '|';
  AFields.DelimitedText := AValue;
end;

procedure TWipInstallEngine.CreateShortcutFile(const ALinkFile, ATargetFile: string);
var
  ShellLink: IShellLinkW;
  PersistFile: IPersistFile;
begin
  OleCheck(CoCreateInstance(CLSID_ShellLink, nil, CLSCTX_INPROC_SERVER, IShellLinkW, ShellLink));
  OleCheck(ShellLink.SetPath(PChar(ATargetFile)));
  OleCheck(ShellLink.SetWorkingDirectory(PChar(ExtractFilePath(ATargetFile))));
  PersistFile := ShellLink as IPersistFile;
  OleCheck(PersistFile.Save(PChar(ALinkFile), True));
end;

procedure TWipInstallEngine.BackupExistingFile(const AFileName, ATargetFolder: string; AManifest: TStrings);
var
  BackupFile: string;
  BackupId: TGUID;
begin
  if not TFile.Exists(AFileName) then
    Exit;

  EnsureOwnedDirectory(BackupFolderName(ATargetFolder), ATargetFolder, AManifest);
  CreateGUID(BackupId);
  BackupFile := IncludeTrailingPathDelimiter(BackupFolderName(ATargetFolder)) +
    SafeFileName(ExtractFileName(AFileName)) + '_' + GUIDToString(BackupId) + '.bak';
  TFile.Copy(AFileName, BackupFile, True);
  AManifest.Add('backup=' + AFileName + '|' + BackupFile);
  Log('Backed up existing file: ' + AFileName + ' -> ' + BackupFile);
end;

procedure TWipInstallEngine.WriteRegistryEntry(const AEntry: string; AManifest: TStrings);
var
  Registry: TRegistry;
  KeyName: string;
  ValueName: string;
  ValueData: string;
  OriginalKeyName: string;
  HadExisting: Boolean;
  OldValue: string;
  FirstSep: Integer;
  SecondSep: Integer;
begin
  FirstSep := Pos('|', AEntry);
  SecondSep := Pos('|', Copy(AEntry, FirstSep + 1, MaxInt));
  if (FirstSep <= 0) or (SecondSep <= 0) then
    raise EConvertError.Create('Registry entry must be Key|Name|Value: ' + AEntry);
  Inc(SecondSep, FirstSep);

  KeyName := Copy(AEntry, 1, FirstSep - 1);
  ValueName := Copy(AEntry, FirstSep + 1, SecondSep - FirstSep - 1);
  ValueData := Copy(AEntry, SecondSep + 1, MaxInt);
  OriginalKeyName := KeyName;

  if not KeyName.StartsWith('HKCU\', True) then
    raise EInvalidOperation.Create('Only HKCU registry entries are supported in this build: ' + KeyName);
  KeyName := Copy(KeyName, 6, MaxInt);
  HadExisting := False;
  OldValue := '';

  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    if Registry.OpenKey(KeyName, False) then
    begin
      if Registry.ValueExists(ValueName) then
      begin
        HadExisting := True;
        OldValue := Registry.ReadString(ValueName);
      end;
      Registry.CloseKey;
    end;
    if not Registry.OpenKey(KeyName, True) then
      raise EInOutError.Create('Unable to open registry key: HKCU\' + KeyName);
    Registry.WriteString(ValueName, ValueData);
    AManifest.Add('registry=' + EscapeManifestField(OriginalKeyName) + '|' + EscapeManifestField(ValueName) + '|' +
      BoolToStr(HadExisting, True) + '|' + EscapeManifestField(OldValue) + '|' + EscapeManifestField(ValueData));
  finally
    Registry.Free;
  end;
end;

procedure TWipInstallEngine.DeleteRegistryEntry(const AEntry: string);
var
  Registry: TRegistry;
  KeyName: string;
  ValueName: string;
  HadExisting: Boolean;
  OldValue: string;
  NewValue: string;
  CurrentValue: string;
  Fields: TStringList;
  Sep: Integer;
begin
  Fields := TStringList.Create;
  try
    SplitManifestFields(AEntry, Fields);
    if Fields.Count >= 5 then
    begin
      KeyName := UnescapeManifestField(Fields[0]);
      ValueName := UnescapeManifestField(Fields[1]);
      HadExisting := SameText(Fields[2], 'True');
      OldValue := UnescapeManifestField(Fields[3]);
      NewValue := UnescapeManifestField(Fields[4]);
    end
    else
    begin
      Sep := Pos('|', AEntry);
      if Sep <= 0 then
        Exit;
      KeyName := Copy(AEntry, 1, Sep - 1);
      ValueName := Copy(AEntry, Sep + 1, MaxInt);
      HadExisting := False;
      OldValue := '';
      NewValue := '';
    end;
  finally
    Fields.Free;
  end;

  if not KeyName.StartsWith('HKCU\', True) then
    Exit;
  KeyName := Copy(KeyName, 6, MaxInt);

  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    if Registry.OpenKey(KeyName, False) and Registry.ValueExists(ValueName) then
    begin
      CurrentValue := Registry.ReadString(ValueName);
      if (NewValue <> '') and (CurrentValue <> NewValue) then
      begin
        Log('Skipped changed registry value: HKCU\' + KeyName + '|' + ValueName);
        Exit;
      end;
      if HadExisting then
      begin
        Registry.WriteString(ValueName, OldValue);
        Log('Restored registry value: HKCU\' + KeyName + '|' + ValueName);
      end
      else
      begin
        Registry.DeleteValue(ValueName);
        Log('Deleted registry value: HKCU\' + KeyName + '|' + ValueName);
      end;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TWipInstallEngine.WriteEnvironmentVariable(const AEntry: string; AManifest: TStrings);
var
  Registry: TRegistry;
  NameText: string;
  ValueText: string;
  HadExisting: Boolean;
  OldValue: string;
  Sep: Integer;
begin
  Sep := Pos('|', AEntry);
  if Sep <= 0 then
    raise EConvertError.Create('Environment variable entry must be Name|Value: ' + AEntry);
  NameText := Trim(Copy(AEntry, 1, Sep - 1));
  ValueText := Copy(AEntry, Sep + 1, MaxInt);
  if NameText = '' then
    raise EInvalidOperation.Create('Environment variable name cannot be blank.');
  if NameText.Contains('=') then
    raise EInvalidOperation.Create('Environment variable name cannot contain "=": ' + NameText);

  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    HadExisting := False;
    OldValue := '';
    if Registry.OpenKey('Environment', False) then
    begin
      if Registry.ValueExists(NameText) then
      begin
        HadExisting := True;
        OldValue := Registry.ReadString(NameText);
      end;
      Registry.CloseKey;
    end;
    if not Registry.OpenKey('Environment', True) then
      raise EInOutError.Create('Unable to open HKCU\Environment.');
    Registry.WriteString(NameText, ValueText);
    AManifest.Add('environment=' + EscapeManifestField(NameText) + '|' + BoolToStr(HadExisting, True) + '|' +
      EscapeManifestField(OldValue) + '|' + EscapeManifestField(ValueText));
    Log('Wrote environment variable: ' + NameText);
  finally
    Registry.Free;
  end;
end;

procedure TWipInstallEngine.DeleteEnvironmentVariable(const AName: string);
var
  Registry: TRegistry;
  Fields: TStringList;
  NameText: string;
  HadExisting: Boolean;
  OldValue: string;
  NewValue: string;
  CurrentValue: string;
begin
  NameText := AName;
  HadExisting := False;
  OldValue := '';
  NewValue := '';
  Fields := TStringList.Create;
  try
    SplitManifestFields(AName, Fields);
    if Fields.Count >= 4 then
    begin
      NameText := UnescapeManifestField(Fields[0]);
      HadExisting := SameText(Fields[1], 'True');
      OldValue := UnescapeManifestField(Fields[2]);
      NewValue := UnescapeManifestField(Fields[3]);
    end;
  finally
    Fields.Free;
  end;

  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    if Registry.OpenKey('Environment', False) and Registry.ValueExists(NameText) then
    begin
      CurrentValue := Registry.ReadString(NameText);
      if (NewValue <> '') and (CurrentValue <> NewValue) then
      begin
        Log('Skipped changed environment variable: ' + NameText);
        Exit;
      end;
      if HadExisting then
      begin
        Registry.WriteString(NameText, OldValue);
        Log('Restored environment variable: ' + NameText);
      end
      else
      begin
        Registry.DeleteValue(NameText);
        Log('Deleted environment variable: ' + NameText);
      end;
    end;
  finally
    Registry.Free;
  end;
end;

function TWipInstallEngine.ResolvePathEntry(const AEntry, ATargetFolder: string): string;
begin
  Result := Trim(AEntry);
  Result := StringReplace(Result, '{app}', IncludeTrailingPathDelimiter(ATargetFolder), [rfReplaceAll, rfIgnoreCase]);
  Result := StringReplace(Result, '{target}', IncludeTrailingPathDelimiter(ATargetFolder), [rfReplaceAll, rfIgnoreCase]);
  if (Result <> '') and not TPath.IsPathRooted(Result) then
    Result := TPath.GetFullPath(IncludeTrailingPathDelimiter(ATargetFolder) + Result)
  else if Result <> '' then
    Result := TPath.GetFullPath(Result);
  Result := ExcludeTrailingPathDelimiter(Result);
end;

function TWipInstallEngine.PathContainsEntry(const APathValue, AEntry: string): Boolean;
var
  Parts: TStringList;
  I: Integer;
begin
  Result := False;
  Parts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ';';
    Parts.DelimitedText := APathValue;
    for I := 0 to Parts.Count - 1 do
      if SameText(ExcludeTrailingPathDelimiter(Trim(Parts[I])), ExcludeTrailingPathDelimiter(Trim(AEntry))) then
        Exit(True);
  finally
    Parts.Free;
  end;
end;

function TWipInstallEngine.RemovePathEntry(const APathValue, AEntry: string): string;
var
  Parts: TStringList;
  OutputParts: TStringList;
  I: Integer;
  PartText: string;
begin
  Parts := TStringList.Create;
  OutputParts := TStringList.Create;
  try
    Parts.StrictDelimiter := True;
    Parts.Delimiter := ';';
    Parts.DelimitedText := APathValue;
    OutputParts.StrictDelimiter := True;
    OutputParts.Delimiter := ';';
    for I := 0 to Parts.Count - 1 do
    begin
      PartText := Trim(Parts[I]);
      if (PartText <> '') and not SameText(ExcludeTrailingPathDelimiter(PartText),
        ExcludeTrailingPathDelimiter(Trim(AEntry))) then
        OutputParts.Add(PartText);
    end;
    Result := '';
    for I := 0 to OutputParts.Count - 1 do
    begin
      if Result <> '' then
        Result := Result + ';';
      Result := Result + OutputParts[I];
    end;
  finally
    OutputParts.Free;
    Parts.Free;
  end;
end;

procedure TWipInstallEngine.WritePathEntry(const AEntry, ATargetFolder: string; AManifest: TStrings);
var
  Registry: TRegistry;
  EntryText: string;
  HadExisting: Boolean;
  OldValue: string;
  NewValue: string;
begin
  EntryText := ResolvePathEntry(AEntry, ATargetFolder);
  if EntryText = '' then
    raise EInvalidOperation.Create('PATH entry cannot be blank.');
  if EntryText.Contains(';') then
    raise EInvalidOperation.Create('PATH entry cannot contain semicolons: ' + EntryText);

  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    HadExisting := False;
    OldValue := '';
    if Registry.OpenKey('Environment', False) then
    begin
      if Registry.ValueExists('Path') then
      begin
        HadExisting := True;
        OldValue := Registry.ReadString('Path');
      end;
      Registry.CloseKey;
    end;

    NewValue := OldValue;
    if not PathContainsEntry(NewValue, EntryText) then
    begin
      if Trim(NewValue) = '' then
        NewValue := EntryText
      else
        NewValue := NewValue + ';' + EntryText;
    end;

    if not Registry.OpenKey('Environment', True) then
      raise EInOutError.Create('Unable to open HKCU\Environment.');
    Registry.WriteString('Path', NewValue);
    AManifest.Add('pathentry=' + EscapeManifestField(EntryText) + '|' + BoolToStr(HadExisting, True) + '|' +
      EscapeManifestField(OldValue) + '|' + EscapeManifestField(NewValue));
    Log('Added PATH entry: ' + EntryText);
  finally
    Registry.Free;
  end;
end;

procedure TWipInstallEngine.DeletePathEntry(const AEntry: string);
var
  Registry: TRegistry;
  Fields: TStringList;
  EntryText: string;
  HadExisting: Boolean;
  OldValue: string;
  NewValue: string;
  CurrentValue: string;
  UpdatedValue: string;
begin
  Fields := TStringList.Create;
  try
    SplitManifestFields(AEntry, Fields);
    if Fields.Count >= 4 then
    begin
      EntryText := UnescapeManifestField(Fields[0]);
      HadExisting := SameText(Fields[1], 'True');
      OldValue := UnescapeManifestField(Fields[2]);
      NewValue := UnescapeManifestField(Fields[3]);
    end
    else
    begin
      EntryText := AEntry;
      HadExisting := False;
      OldValue := '';
      NewValue := '';
    end;
  finally
    Fields.Free;
  end;

  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    if Registry.OpenKey('Environment', False) and Registry.ValueExists('Path') then
    begin
      CurrentValue := Registry.ReadString('Path');
      Registry.CloseKey;
      if not Registry.OpenKey('Environment', True) then
        raise EInOutError.Create('Unable to open HKCU\Environment.');
      if (NewValue <> '') and SameText(CurrentValue, NewValue) then
      begin
        if HadExisting then
          Registry.WriteString('Path', OldValue)
        else
          Registry.DeleteValue('Path');
        Log('Restored PATH after removing: ' + EntryText);
      end
      else
      begin
        UpdatedValue := RemovePathEntry(CurrentValue, EntryText);
        if UpdatedValue <> CurrentValue then
        begin
          if UpdatedValue = '' then
            Registry.DeleteValue('Path')
          else
            Registry.WriteString('Path', UpdatedValue);
          Log('Removed PATH entry: ' + EntryText);
        end
        else
          Log('PATH entry already absent: ' + EntryText);
      end;
    end;
  finally
    Registry.Free;
  end;
end;

procedure TWipInstallEngine.WriteFileAssociation(const AEntry, ATargetFolder: string; AManifest: TStrings);
var
  Registry: TRegistry;
  ExtensionText: string;
  DescriptionText: string;
  TargetText: string;
  ProgId: string;
  OldDefault: string;
  HadOldDefault: Boolean;
  FirstSep: Integer;
  SecondSep: Integer;
begin
  FirstSep := Pos('|', AEntry);
  SecondSep := Pos('|', Copy(AEntry, FirstSep + 1, MaxInt));
  if (FirstSep <= 0) or (SecondSep <= 0) then
    raise EConvertError.Create('File association must be Extension|Description|Target: ' + AEntry);
  Inc(SecondSep, FirstSep);

  ExtensionText := Trim(Copy(AEntry, 1, FirstSep - 1));
  DescriptionText := Copy(AEntry, FirstSep + 1, SecondSep - FirstSep - 1);
  TargetText := Copy(AEntry, SecondSep + 1, MaxInt);
  if not ExtensionText.StartsWith('.') then
    ExtensionText := '.' + ExtensionText;
  if ExtensionText.Contains('\') or ExtensionText.Contains('|') then
    raise EInvalidOperation.Create('Invalid file extension: ' + ExtensionText);
  if not TPath.IsPathRooted(TargetText) then
    TargetText := IncludeTrailingPathDelimiter(ATargetFolder) + TargetText;

  ProgId := 'PackageStudioPro.' + SafeFileName(ExtensionText.Substring(1));
  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    HadOldDefault := False;
    OldDefault := '';
    if Registry.OpenKey('Software\Classes\' + ExtensionText, False) then
    begin
      if Registry.ValueExists('') then
      begin
        HadOldDefault := True;
        OldDefault := Registry.ReadString('');
      end;
      Registry.CloseKey;
    end;

    if not Registry.OpenKey('Software\Classes\' + ExtensionText, True) then
      raise EInOutError.Create('Unable to open association extension key.');
    Registry.WriteString('', ProgId);
    Registry.CloseKey;

    if not Registry.OpenKey('Software\Classes\' + ProgId, True) then
      raise EInOutError.Create('Unable to open association ProgID key.');
    Registry.WriteString('', DescriptionText);
    Registry.CloseKey;

    if not Registry.OpenKey('Software\Classes\' + ProgId + '\shell\open\command', True) then
      raise EInOutError.Create('Unable to open association command key.');
    Registry.WriteString('', '"' + TargetText + '" "%1"');
    Registry.CloseKey;

    AManifest.Add('association=' + EscapeManifestField(ExtensionText) + '|' + EscapeManifestField(ProgId) + '|' +
      BoolToStr(HadOldDefault, True) + '|' + EscapeManifestField(OldDefault));
    Log('Wrote file association: ' + ExtensionText + ' -> ' + TargetText);
  finally
    Registry.Free;
  end;
end;

procedure TWipInstallEngine.DeleteFileAssociation(const AEntry: string);
var
  Registry: TRegistry;
  ExtensionText: string;
  ProgId: string;
  HadOldDefault: Boolean;
  OldDefault: string;
  CurrentDefault: string;
  Fields: TStringList;
  Sep: Integer;
begin
  Fields := TStringList.Create;
  try
    SplitManifestFields(AEntry, Fields);
    if Fields.Count >= 4 then
    begin
      ExtensionText := UnescapeManifestField(Fields[0]);
      ProgId := UnescapeManifestField(Fields[1]);
      HadOldDefault := SameText(Fields[2], 'True');
      OldDefault := UnescapeManifestField(Fields[3]);
    end
    else
    begin
      Sep := Pos('|', AEntry);
      if Sep <= 0 then
        Exit;
      ExtensionText := Copy(AEntry, 1, Sep - 1);
      ProgId := Copy(AEntry, Sep + 1, MaxInt);
      HadOldDefault := False;
      OldDefault := '';
    end;
  finally
    Fields.Free;
  end;

  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    if Registry.OpenKey('Software\Classes\' + ExtensionText, False) then
    begin
      if Registry.ValueExists('') then
        CurrentDefault := Registry.ReadString('')
      else
        CurrentDefault := '';
      Registry.CloseKey;
      if CurrentDefault <> ProgId then
      begin
        Log('Skipped changed file association: ' + ExtensionText);
        Exit;
      end;
    end;
    if HadOldDefault then
    begin
      if Registry.OpenKey('Software\Classes\' + ExtensionText, True) then
      begin
        Registry.WriteString('', OldDefault);
        Registry.CloseKey;
        Log('Restored file association: ' + ExtensionText);
      end;
    end
    else if Registry.KeyExists('Software\Classes\' + ExtensionText) then
      Registry.DeleteKey('Software\Classes\' + ExtensionText);

    if Registry.KeyExists('Software\Classes\' + ProgId) then
      Registry.DeleteKey('Software\Classes\' + ProgId);
    Log('Deleted file association: ' + ExtensionText);
  finally
    Registry.Free;
  end;
end;

function TWipInstallEngine.UninstallRegistryKeyName(AProject: TWipProject): string;
begin
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\PackageStudioPro_' +
    SafeFileName(AProject.ProductName);
end;

procedure TWipInstallEngine.WriteUninstallRegistration(AProject: TWipProject; const ATargetFolder: string; AManifest: TStrings);
var
  Registry: TRegistry;
  KeyName: string;
  UninstallCommand: string;
begin
  KeyName := UninstallRegistryKeyName(AProject);
  UninstallCommand := '"' + TPath.Combine(ATargetFolder, '.package-studio\WipRuntime.exe') + '" "' +
    TPath.Combine(ATargetFolder, '.package-studio\uninstall.wiproj') + '" --uninstall';

  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    if not Registry.OpenKey(KeyName, True) then
      raise EInOutError.Create('Unable to open uninstall registry key: HKCU\' + KeyName);
    Registry.WriteString('DisplayName', AProject.ProductName);
    Registry.WriteString('DisplayVersion', AProject.Version);
    Registry.WriteString('Publisher', AProject.Publisher);
    Registry.WriteString('InstallLocation', ATargetFolder);
    Registry.WriteString('UninstallString', UninstallCommand);
    Registry.WriteString('DisplayIcon', TPath.Combine(ATargetFolder, '.package-studio\WipRuntime.exe'));
    Registry.WriteInteger('NoModify', 1);
    Registry.WriteInteger('NoRepair', 1);
    AManifest.Add('uninstallkey=HKCU\' + KeyName);
    Log('Registered uninstall entry: HKCU\' + KeyName);
  finally
    Registry.Free;
  end;
end;

procedure TWipInstallEngine.DeleteUninstallRegistration(const AKeyName: string);
var
  Registry: TRegistry;
  KeyName: string;
begin
  if not AKeyName.StartsWith('HKCU\', True) then
    Exit;
  KeyName := Copy(AKeyName, 6, MaxInt);

  Registry := TRegistry.Create(KEY_READ or KEY_WRITE);
  try
    Registry.RootKey := HKEY_CURRENT_USER;
    if Registry.KeyExists(KeyName) then
    begin
      Registry.DeleteKey(KeyName);
      Log('Deleted uninstall entry: HKCU\' + KeyName);
    end;
  finally
    Registry.Free;
  end;
end;

procedure TWipInstallEngine.ValidateManagedPath(const AFileName, ATargetFolder: string);
var Candidate, Root, Parent: string; Attributes: DWORD;
begin
  Candidate := TPath.GetFullPath(AFileName);
  Root := IncludeTrailingPathDelimiter(TPath.GetFullPath(ATargetFolder));
  if not Candidate.StartsWith(Root, True) and
     not (SameText(ExtractFileExt(Candidate), '.lnk') and
       (SameText(ExtractFilePath(Candidate), IncludeTrailingPathDelimiter(ShortcutFolderForLocation('Desktop', ATargetFolder))) or
        SameText(ExtractFilePath(Candidate), IncludeTrailingPathDelimiter(ShortcutFolderForLocation('StartMenu', ATargetFolder))))) then
    raise EInvalidOperation.Create('Managed path is outside the installation: ' + Candidate);
  Parent := Candidate;
  while Parent <> '' do begin
    Attributes := GetFileAttributes(PChar(Parent));
    if (Attributes <> INVALID_FILE_ATTRIBUTES) and ((Attributes and FILE_ATTRIBUTE_REPARSE_POINT) <> 0) then
      raise EInvalidOperation.Create('Refusing a reparse point: ' + Parent);
    Candidate := ExcludeTrailingPathDelimiter(ExtractFilePath(Parent));
    if SameText(Candidate, Parent) then Break;
    Parent := Candidate;
  end;
end;

procedure TWipInstallEngine.CheckPrerequisites(AProject: TWipProject);
const RuntimeKey = 'Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}';
var Entry, Name, Method, Address: string; Parts: TArray<string>;
  Registry: TRegistry; Present: Boolean; RootKey: HKEY; View: Cardinal;
  SystemFolder: array[0..MAX_PATH] of Char; Wow64Process: BOOL; NativeInfo: TSystemInfo;
begin
  for Entry in AProject.Prerequisites do begin
    Parts := Entry.Split(['|']);
    if Length(Parts) < 2 then raise EInvalidOperation.Create('Prerequisite must use Name|Method|Help URL.');
    Name := Parts[0]; Method := Parts[1]; Address := '';
    if Length(Parts) > 2 then Address := Parts[2];
    Present := False;
    if SameText(Method, 'Windows10') then Present := TOSVersion.Check(10)
    else if SameText(Method, 'Windows-x64') then begin
      GetNativeSystemInfo(NativeInfo);
      Present := NativeInfo.wProcessorArchitecture = PROCESSOR_ARCHITECTURE_AMD64;
    end else if SameText(Method, 'WebView2') then begin
      for RootKey in TArray<HKEY>.Create(HKEY_CURRENT_USER, HKEY_LOCAL_MACHINE) do
        for View in TArray<Cardinal>.Create(KEY_WOW64_32KEY, KEY_WOW64_64KEY) do begin
          Registry := TRegistry.Create(KEY_READ or View);
          try
            Registry.RootKey := RootKey;
            if Registry.OpenKeyReadOnly(RuntimeKey) and Registry.ValueExists('pv') then
              Present := Present or ((Registry.ReadString('pv') <> '') and (Registry.ReadString('pv') <> '0.0.0.0'));
          finally Registry.Free end;
        end;
    end else if SameText(Method, 'OpenSSH-Optional') then begin
      if GetSystemDirectory(SystemFolder, Length(SystemFolder)) = 0 then RaiseLastOSError;
      Address := TPath.Combine(string(SystemFolder), 'OpenSSH\sftp.exe');
      Wow64Process := False;
      if IsWow64Process(GetCurrentProcess, Wow64Process) and Wow64Process then begin
        if GetWindowsDirectory(SystemFolder, Length(SystemFolder)) = 0 then RaiseLastOSError;
        Address := TPath.Combine(string(SystemFolder), 'Sysnative\OpenSSH\sftp.exe');
      end;
      if TFile.Exists(Address) then Log(Name + ': available.')
      else Log(Name + ': optional Windows OpenSSH Client is not installed; SFTP needs it. Local editing remains available.');
      Continue;
    end else if SameText(Method, 'Manual') then
      raise EInvalidOperation.Create('Confirm/install this prerequisite before proceeding: ' + Name + ' ' + Address)
    else raise EInvalidOperation.Create('Unsupported prerequisite detection method: ' + Method);
    if not Present then raise EInvalidOperation.Create('Required prerequisite is missing: ' + Name + '. Install it from ' + Address + ' and run Setup again.');
    Log(Name + ': detected.');
  end;
end;

procedure TWipInstallEngine.EnsureOwnedDirectory(const AFolder, ATargetFolder: string; AManifest: TStrings);
var Folder, Parent, Root: string; Created: TStringList; I: Integer;
begin
  Root := IncludeTrailingPathDelimiter(TPath.GetFullPath(ATargetFolder));
  Folder := ExcludeTrailingPathDelimiter(TPath.GetFullPath(AFolder));
  Created := TStringList.Create;
  try
    while not TDirectory.Exists(Folder) and
      (SameText(Folder, ExcludeTrailingPathDelimiter(Root)) or Folder.StartsWith(Root, True)) do begin
      Created.Insert(0, 'folder=' + Folder);
      if SameText(Folder, ExcludeTrailingPathDelimiter(Root)) then Break;
      Parent := ExcludeTrailingPathDelimiter(ExtractFilePath(Folder));
      if SameText(Parent, Folder) then Break;
      Folder := Parent;
    end;
    ForceDirectories(AFolder);
    for I := 0 to Created.Count - 1 do AManifest.Add(Created[I]);
  finally Created.Free end;
end;

procedure TWipInstallEngine.RollbackManifest(AManifest: TStrings; const ATargetFolder: string);
var
  I: Integer;
  Entry: string;
  FileName: string;
  BackupName: string;
  Sep: Integer;
begin
  Log('Install failed. Rolling back completed operations.');
  for I := AManifest.Count - 1 downto 0 do
  begin
    Entry := AManifest[I];
    if Entry.StartsWith('file=') then
    begin
      FileName := Entry.Substring(5);
      Sep := LastDelimiter('|', FileName);
      if Sep > 0 then FileName := Copy(FileName, 1, Sep - 1);
      ValidateManagedPath(FileName, ATargetFolder);
      if TFile.Exists(FileName) then
      begin
        TFile.Delete(FileName);
        Log('Rollback deleted: ' + FileName);
      end;
    end
    else if Entry.StartsWith('registry=') then
      DeleteRegistryEntry(Entry.Substring(9));
    if Entry.StartsWith('environment=') then
      DeleteEnvironmentVariable(Entry.Substring(12));
    if Entry.StartsWith('pathentry=') then
      DeletePathEntry(Entry.Substring(10));
    if Entry.StartsWith('association=') then
      DeleteFileAssociation(Entry.Substring(12));
    if Entry.StartsWith('uninstallkey=') then
      DeleteUninstallRegistration(Entry.Substring(13));
    if Entry.StartsWith('folder=') then begin
      FileName := Entry.Substring(7);
      ValidateManagedPath(TPath.Combine(FileName, '.ownership-check'), ATargetFolder);
      if TDirectory.Exists(FileName) and TDirectory.IsEmpty(FileName) then TDirectory.Delete(FileName);
    end;
    if Entry.StartsWith('backup=') then
    begin
      FileName := Entry.Substring(7);
      Sep := LastDelimiter('|', FileName);
      if Sep > 0 then
      begin
        BackupName := Copy(FileName, Sep + 1, MaxInt);
        FileName := Copy(FileName, 1, Sep - 1);
        if TFile.Exists(BackupName) and not TFile.Exists(FileName) then
        begin
          ForceDirectories(ExtractFilePath(FileName));
          TFile.Move(BackupName, FileName);
          Log('Rollback restored: ' + FileName);
        end;
      end;
    end;
  end;

end;

procedure TWipInstallEngine.Log(const AMessage: string);
begin
  if FLog <> nil then
    FLog.Add(AMessage);
  if Assigned(FOnLog) then
    FOnLog(AMessage);
end;

procedure TWipInstallEngine.ExecuteInstall(AProject: TWipProject; const ATargetFolder: string; AMode: TWipInstallMode);
var
  I: Integer;
  Manifest, PreviousManifest, FinalManifest, RetiredBackups: TStringList;
  SourceFile, SupportFolder, SupportFile, BackupPath: string;
  PreviousIndex, BackupIndex: Integer;
  TargetFile: string;
  ShortcutEntry: string;
  ShortcutLocation: string;
  ShortcutName: string;
  ShortcutTarget: string;
  ShortcutFile: string;
  ShortcutFolder: string;
  RegistryEntry: string;
  EnvironmentEntry: string;
  PathEntry: string;
  AssociationEntry: string;
  Sep: Integer;
  ComInitialized: Boolean;
  InstallLike: Boolean;
  PreviousProject: TWipProject;
begin
  InstallLike := AMode in [imInstall, imRepair];
  if (AMode = imRepair) and not TFile.Exists(ManifestFileName(ATargetFolder)) then
    raise EInvalidOperation.Create('Repair requires an existing install manifest: ' + ManifestFileName(ATargetFolder));

  if InstallLike then begin
    ValidateManagedPath(TPath.Combine(ATargetFolder, 'PackageStudioPro.install-manifest'), ATargetFolder);
    CheckPrerequisites(AProject);
    // Folder ownership is recorded once the transaction journal exists.
  end;

  Manifest := TStringList.Create;
  PreviousManifest := TStringList.Create;
  FinalManifest := TStringList.Create;
  RetiredBackups := TStringList.Create;
  try
    if TFile.Exists(ManifestFileName(ATargetFolder)) then begin
      PreviousManifest.LoadFromFile(ManifestFileName(ATargetFolder), TEncoding.UTF8);
      if PreviousManifest.Values['product'] <> AProject.ProductName then
        raise EInvalidOperation.Create('The destination belongs to another product. Choose a separate folder.');
    end;
    try
      Manifest.Add('product=' + AProject.ProductName);
      Manifest.Add('version=' + AProject.Version);
      Manifest.Add('installFolder=' + ATargetFolder);
      if InstallLike then EnsureOwnedDirectory(ATargetFolder, ATargetFolder, Manifest);

      for I := 0 to AProject.Files.Count - 1 do
      begin
        SourceFile := ResolveSourceFile(AProject.Files[I]);
        TargetFile := ResolveTargetFile(ATargetFolder, AProject.Files[I]);
        ValidateManagedPath(TargetFile, ATargetFolder);
        if InstallLike then
        begin
          EnsureOwnedDirectory(ExtractFilePath(TargetFile), ATargetFolder, Manifest);
          if AMode = imInstall then
            BackupExistingFile(TargetFile, ATargetFolder, Manifest);
          TFile.Copy(SourceFile, TargetFile, True);
          Manifest.Add(ManifestFileEntry(TargetFile));
          Log('Copied: ' + SourceFile + ' -> ' + TargetFile);
        end
        else
          Log('Would copy: ' + SourceFile + ' -> ' + TargetFile);
      end;

    if AProject.Files.Count = 0 then
      Log('No payload files are defined yet.');

    if AProject.Shortcuts.Count = 0 then
      Log('No shortcuts are defined yet.')
    else
    begin
      ComInitialized := False;
      if InstallLike then
      begin
        OleCheck(CoInitialize(nil));
        ComInitialized := True;
      end;
      try
        for I := 0 to AProject.Shortcuts.Count - 1 do
        begin
          ShortcutEntry := AProject.Shortcuts[I];
          Sep := Pos('|', ShortcutEntry);
          if Sep > 0 then
          begin
            ShortcutLocation := Copy(ShortcutEntry, 1, Sep - 1);
            ShortcutEntry := Copy(ShortcutEntry, Sep + 1, MaxInt);
            Sep := Pos('|', ShortcutEntry);
            if Sep > 0 then
            begin
              ShortcutName := Copy(ShortcutEntry, 1, Sep - 1);
              ShortcutTarget := Copy(ShortcutEntry, Sep + 1, MaxInt);
            end
            else
            begin
              ShortcutName := ShortcutLocation;
              ShortcutTarget := ShortcutEntry;
              ShortcutLocation := 'InstallFolder';
            end;
          end
          else
          begin
            ShortcutLocation := 'InstallFolder';
            ShortcutName := ShortcutEntry;
            ShortcutTarget := ShortcutEntry;
          end;

          if not TPath.IsPathRooted(ShortcutTarget) then
            ShortcutTarget := IncludeTrailingPathDelimiter(ATargetFolder) + ShortcutTarget;
          if InstallLike and not TFile.Exists(ShortcutTarget) then
            raise EFileNotFoundException.Create('Shortcut target not found: ' + ShortcutTarget);
          ShortcutFolder := ShortcutFolderForLocation(ShortcutLocation, ATargetFolder);
          if InstallLike then
            EnsureOwnedDirectory(ShortcutFolder, ATargetFolder, Manifest);
          ShortcutFile := IncludeTrailingPathDelimiter(ShortcutFolder) + SafeFileName(ShortcutName) + '.lnk';
          ValidateManagedPath(ShortcutFile, ATargetFolder);

          if InstallLike then
          begin
            if (AMode = imRepair) and TFile.Exists(ShortcutFile) then
            begin
              Log('Repair kept existing shortcut: ' + ShortcutFile);
              Continue;
            end;
            if AMode = imInstall then
              BackupExistingFile(ShortcutFile, ATargetFolder, Manifest);
            CreateShortcutFile(ShortcutFile, ShortcutTarget);
            Manifest.Add(ManifestFileEntry(ShortcutFile));
            Log('Created shortcut: ' + ShortcutFile + ' -> ' + ShortcutTarget);
          end
          else
            Log('Would create shortcut: ' + ShortcutFile + ' -> ' + ShortcutTarget);
        end;
      finally
        if ComInitialized then
          CoUninitialize;
      end;
    end;

    if AProject.RegistryEntries.Count = 0 then
      Log('No registry entries are defined yet.')
    else
      for I := 0 to AProject.RegistryEntries.Count - 1 do
      begin
        RegistryEntry := AProject.RegistryEntries[I];
        if AMode = imInstall then
        begin
          WriteRegistryEntry(RegistryEntry, Manifest);
          Log('Wrote registry entry: ' + RegistryEntry);
        end
        else if AMode = imRepair then
          Log('Repair preserved existing registry state: ' + RegistryEntry)
        else
          Log('Would write registry entry: ' + RegistryEntry);
      end;

    if AProject.EnvironmentVariables.Count = 0 then
      Log('No environment variables are defined yet.')
    else
      for I := 0 to AProject.EnvironmentVariables.Count - 1 do
      begin
        EnvironmentEntry := AProject.EnvironmentVariables[I];
        if AMode = imInstall then
          WriteEnvironmentVariable(EnvironmentEntry, Manifest)
        else if AMode = imRepair then
          Log('Repair preserved existing environment variable: ' + EnvironmentEntry)
        else
          Log('Would write environment variable: ' + EnvironmentEntry);
      end;

    if AProject.PathEntries.Count = 0 then
      Log('No PATH entries are defined yet.')
    else
      for I := 0 to AProject.PathEntries.Count - 1 do
      begin
        PathEntry := AProject.PathEntries[I];
        if AMode = imInstall then
          WritePathEntry(PathEntry, ATargetFolder, Manifest)
        else if AMode = imRepair then
          Log('Repair preserved existing PATH entry: ' + PathEntry)
        else
          Log('Would add PATH entry: ' + ResolvePathEntry(PathEntry, ATargetFolder));
      end;

    if AProject.FileAssociations.Count = 0 then
      Log('No file associations are defined yet.')
    else
      for I := 0 to AProject.FileAssociations.Count - 1 do
      begin
        AssociationEntry := AProject.FileAssociations[I];
        if AMode = imInstall then
          WriteFileAssociation(AssociationEntry, ATargetFolder, Manifest)
        else if AMode = imRepair then
          Log('Repair preserved existing file association: ' + AssociationEntry)
        else
          Log('Would write file association: ' + AssociationEntry);
      end;

    if AProject.Prerequisites.Count = 0 then
      Log('No prerequisites are defined yet.')
    else
      for I := 0 to AProject.Prerequisites.Count - 1 do
        Log('Prerequisite listed: ' + AProject.Prerequisites[I]);

    if AProject.Features.Count = 0 then
      Log('No features are defined yet.')
    else
      for I := 0 to AProject.Features.Count - 1 do
        Log('Feature listed: ' + AProject.Features[I]);

      if AMode = imInstall then
      begin
        SupportFolder := TPath.Combine(ATargetFolder, '.package-studio');
        EnsureOwnedDirectory(SupportFolder, ATargetFolder, Manifest);
        SupportFile := TPath.Combine(SupportFolder, 'WipRuntime.exe');
        ValidateManagedPath(SupportFile, ATargetFolder);
        BackupExistingFile(SupportFile, ATargetFolder, Manifest);
        TFile.Copy(TPath.Combine(FBaseFolder, 'WipRuntime.exe'), SupportFile, True);
        Manifest.Add(ManifestFileEntry(SupportFile));
        SupportFile := TPath.Combine(SupportFolder, 'uninstall.wiproj');
        ValidateManagedPath(SupportFile, ATargetFolder);
        BackupExistingFile(SupportFile, ATargetFolder, Manifest);
        AProject.SaveToFile(SupportFile);
        Manifest.Add(ManifestFileEntry(SupportFile));
        WriteUninstallRegistration(AProject, ATargetFolder, Manifest);
        // Keep the complete rollback journal until the new manifest is committed.
        FinalManifest.Assign(Manifest);
        for BackupIndex := FinalManifest.Count - 1 downto 0 do
          if FinalManifest[BackupIndex].StartsWith('backup=') then begin
            BackupPath := FinalManifest[BackupIndex].Substring(7);
            Sep := LastDelimiter('|', BackupPath);
            TargetFile := Copy(BackupPath, 1, Sep - 1);
            for PreviousIndex := 0 to PreviousManifest.Count - 1 do
              if PreviousManifest[PreviousIndex].StartsWith('file=' + TargetFile + '|', True) then begin
                RetiredBackups.Add(Copy(BackupPath, Sep + 1, MaxInt));
                FinalManifest.Delete(BackupIndex);
                Break;
              end;
          end;
        // Older state records precede new ones so uninstall reverses upgrades
        // before restoring the original pre-install state.
        for PreviousIndex := PreviousManifest.Count - 1 downto 0 do begin
          SourceFile := PreviousManifest[PreviousIndex];
          if SourceFile.StartsWith('file=') then begin
            TargetFile := Copy(SourceFile, 6, LastDelimiter('|', SourceFile) - 6);
            for BackupIndex := 0 to FinalManifest.Count - 1 do
              if FinalManifest[BackupIndex].StartsWith('file=' + TargetFile + '|', True) then begin TargetFile := ''; Break end;
            if TargetFile <> '' then FinalManifest.Insert(0, SourceFile);
          end else if not SourceFile.StartsWith('product=') and not SourceFile.StartsWith('version=') and
              not SourceFile.StartsWith('installFolder=') and not SourceFile.StartsWith('uninstallkey=') then
            FinalManifest.Insert(0, SourceFile);
        end;
        FinalManifest.SaveToFile(ManifestFileName(ATargetFolder) + '.new', TEncoding.UTF8);
        if not MoveFileEx(PChar(ManifestFileName(ATargetFolder) + '.new'), PChar(ManifestFileName(ATargetFolder)),
          MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH) then RaiseLastOSError;
        for BackupPath in RetiredBackups do begin
          ValidateManagedPath(BackupPath, ATargetFolder);
          try TFile.Delete(BackupPath) except on E: Exception do Log('Backup cleanup deferred: ' + E.Message) end;
        end;
        Log('Wrote install manifest: ' + ManifestFileName(ATargetFolder));
      end;
      if AMode = imRepair then
        Log('Repair completed; original install manifest preserved.');
    except
      on E: Exception do
      begin
        if AMode = imInstall then begin
          RollbackManifest(Manifest, ATargetFolder);
          if PreviousManifest.Count > 0 then begin
            SupportFile := TPath.Combine(ATargetFolder, '.package-studio\uninstall.wiproj');
            if TFile.Exists(SupportFile) then begin
              PreviousProject := TWipProject.Create;
              try
                PreviousProject.LoadFromFile(SupportFile);
                WriteUninstallRegistration(PreviousProject, ATargetFolder, FinalManifest);
              finally PreviousProject.Free end;
            end;
          end;
        end;
        raise;
      end;
    end;
  finally
    RetiredBackups.Free;
    FinalManifest.Free;
    PreviousManifest.Free;
    Manifest.Free;
  end;
end;

procedure TWipInstallEngine.ExecuteVerify(AProject: TWipProject; const ATargetFolder: string);
var
  I: Integer;
  Manifest: TStringList;
  Entry: string;
  FileName: string;
  ExpectedHash: string;
  Sep: Integer;
  Failed: Boolean;
begin
  Failed := False;
  if not TDirectory.Exists(ATargetFolder) then
  begin
    Log('Verify failed: install folder is missing: ' + ATargetFolder);
    raise EInvalidOperation.Create('Verify failed: install folder is missing: ' + ATargetFolder);
  end;

  if not TFile.Exists(ManifestFileName(ATargetFolder)) then
  begin
    Log('Verify failed: install manifest is missing: ' + ManifestFileName(ATargetFolder));
    raise EInvalidOperation.Create('Verify failed: install manifest is missing: ' + ManifestFileName(ATargetFolder));
  end;

  Manifest := TStringList.Create;
  try
    Manifest.LoadFromFile(ManifestFileName(ATargetFolder), TEncoding.UTF8);
    for I := 0 to Manifest.Count - 1 do
    begin
      Entry := Manifest[I];
      if Entry.StartsWith('file=') then
      begin
        FileName := Entry.Substring(5);
        ExpectedHash := '';
        Sep := LastDelimiter('|', FileName);
        if Sep > 0 then
        begin
          ExpectedHash := Copy(FileName, Sep + 1, MaxInt);
          FileName := Copy(FileName, 1, Sep - 1);
        end;
        if not TFile.Exists(FileName) then
        begin
          Log('Verify missing file: ' + FileName);
          Failed := True;
        end
        else if (ExpectedHash <> '') and (CompareText(FileHash(FileName), ExpectedHash) <> 0) then
        begin
          Log('Verify hash mismatch: ' + FileName);
          Failed := True;
        end
        else
          Log('Verify OK: ' + FileName);
      end;
    end;
  finally
    Manifest.Free;
  end;
  if Failed then
    raise EInvalidOperation.Create('Verify failed. One or more installed files are missing or changed.');
end;

procedure TWipInstallEngine.ExecuteUninstall(const ATargetFolder: string);
var
  Manifest: TStringList;
  I: Integer;
  Entry: string;
  FileName: string;
  ExpectedHash: string;
  BackupName: string;
  Sep: Integer;
begin
  if not TFile.Exists(ManifestFileName(ATargetFolder)) then
  begin
    Log('No install manifest found: ' + ManifestFileName(ATargetFolder));
    Exit;
  end;

  Manifest := TStringList.Create;
  try
    Manifest.LoadFromFile(ManifestFileName(ATargetFolder), TEncoding.UTF8);
    for Entry in Manifest do begin
      if Entry.StartsWith('file=') then begin
        FileName := Entry.Substring(5); Sep := LastDelimiter('|', FileName);
        if Sep <= 0 then raise EInvalidOperation.Create('Invalid file journal entry.');
        ValidateManagedPath(Copy(FileName, 1, Sep - 1), ATargetFolder);
      end else if Entry.StartsWith('folder=') then begin
        ValidateManagedPath(TPath.Combine(Entry.Substring(7), '.ownership-check'), ATargetFolder);
      end else if Entry.StartsWith('backup=') then begin
        FileName := Entry.Substring(7); Sep := LastDelimiter('|', FileName);
        if Sep <= 0 then raise EInvalidOperation.Create('Invalid backup journal entry.');
        ValidateManagedPath(Copy(FileName, 1, Sep - 1), ATargetFolder);
        BackupName := Copy(FileName, Sep + 1, MaxInt);
        ValidateManagedPath(BackupName, ATargetFolder);
        if not TPath.GetFullPath(BackupName).StartsWith(IncludeTrailingPathDelimiter(BackupFolderName(ATargetFolder)), True) then
          raise EInvalidOperation.Create('Backup journal path is outside the backup folder.');
      end;
    end;
    for I := Manifest.Count - 1 downto 0 do
    begin
      Entry := Manifest[I];
      if Entry.StartsWith('file=') then
      begin
        FileName := Entry.Substring(5);
        ExpectedHash := '';
        Sep := LastDelimiter('|', FileName);
        if Sep > 0 then
        begin
          ExpectedHash := Copy(FileName, Sep + 1, MaxInt);
          FileName := Copy(FileName, 1, Sep - 1);
        end;
        if TFile.Exists(FileName) then
        begin
          if (ExpectedHash <> '') and (CompareText(FileHash(FileName), ExpectedHash) <> 0) then
            Log('Skipped modified file: ' + FileName)
          else
          begin
            if SameText(TPath.GetFullPath(FileName), TPath.GetFullPath(ParamStr(0))) then
              Log('Deferred removal of the running uninstaller: ' + FileName)
            else begin
              TFile.Delete(FileName);
              Log('Deleted: ' + FileName);
            end;
          end;
        end
        else
          Log('Already absent: ' + FileName);
      end;
      if Entry.StartsWith('registry=') then
        DeleteRegistryEntry(Entry.Substring(9));
      if Entry.StartsWith('uninstallkey=') then
        DeleteUninstallRegistration(Entry.Substring(13));
      if Entry.StartsWith('environment=') then
        DeleteEnvironmentVariable(Entry.Substring(12));
      if Entry.StartsWith('pathentry=') then
        DeletePathEntry(Entry.Substring(10));
      if Entry.StartsWith('association=') then
        DeleteFileAssociation(Entry.Substring(12));
      if Entry.StartsWith('backup=') then
      begin
        FileName := Entry.Substring(7);
        Sep := LastDelimiter('|', FileName);
        if Sep > 0 then
        begin
          BackupName := Copy(FileName, Sep + 1, MaxInt);
          FileName := Copy(FileName, 1, Sep - 1);
          if TFile.Exists(BackupName) then
          begin
            if TFile.Exists(FileName) then
              Log('Skipped restore because current file remains: ' + FileName)
            else
            begin
              ForceDirectories(ExtractFilePath(FileName));
              TFile.Move(BackupName, FileName);
              Log('Restored pre-install file: ' + FileName);
            end;
          end;
        end;
      end;
    end;
    TFile.Delete(ManifestFileName(ATargetFolder));
    Log('Deleted install manifest.');
    for I := Manifest.Count - 1 downto 0 do
      if Manifest[I].StartsWith('folder=') then begin
        FileName := Manifest[I].Substring(7);
        if TDirectory.Exists(FileName) and TDirectory.IsEmpty(FileName) then TDirectory.Delete(FileName);
      end;
  
  finally
    Manifest.Free;
  end;
end;

procedure TWipInstallEngine.Execute(AProject: TWipProject; AMode: TWipInstallMode);
var
  TargetFolder: string;
begin
  TargetFolder := ExpandInstallFolder(AProject.InstallFolder);
  Log('Product: ' + AProject.ProductName);
  Log('Target: ' + TargetFolder);

  if TWipSafety.IsProtectedInstallFolder(TargetFolder) then
    raise EInvalidOperation.Create('Refusing to install into protected folder: ' + TargetFolder);

  if AMode = imUninstall then
    ExecuteUninstall(TargetFolder)
  else if AMode = imVerify then
    ExecuteVerify(AProject, TargetFolder)
  else
    ExecuteInstall(AProject, TargetFolder, AMode);
end;

end.

