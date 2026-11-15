unit Wip.Project;

interface

uses
  System.Classes, System.Generics.Collections, System.SysUtils, System.JSON;

type
  TWipProject = class
  private
    FFiles: TStringList;
    FShortcuts: TStringList;
    FRegistryEntries: TStringList;
    FEnvironmentVariables: TStringList;
    FPathEntries: TStringList;
    FFileAssociations: TStringList;
    FPrerequisites: TStringList;
    FFeatures: TStringList;
    FProductName: string;
    FPublisher: string;
    FVersion: string;
    FInstallFolder: string;
    FLicenseText: string;
    FSigningEnabled: Boolean;
    FSignToolPath: string;
    FSigningCertificatePath: string;
    FTimestampUrl: string;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure LoadFromFile(const AFileName: string);
    procedure SaveToFile(const AFileName: string);
    function Validate(out AMessage: string): Boolean;
    property ProductName: string read FProductName write FProductName;
    property Publisher: string read FPublisher write FPublisher;
    property Version: string read FVersion write FVersion;
    property InstallFolder: string read FInstallFolder write FInstallFolder;
    property LicenseText: string read FLicenseText write FLicenseText;
    property SigningEnabled: Boolean read FSigningEnabled write FSigningEnabled;
    property SignToolPath: string read FSignToolPath write FSignToolPath;
    property SigningCertificatePath: string read FSigningCertificatePath write FSigningCertificatePath;
    property TimestampUrl: string read FTimestampUrl write FTimestampUrl;
    property Files: TStringList read FFiles;
    property Shortcuts: TStringList read FShortcuts;
    property RegistryEntries: TStringList read FRegistryEntries;
    property EnvironmentVariables: TStringList read FEnvironmentVariables;
    property PathEntries: TStringList read FPathEntries;
    property FileAssociations: TStringList read FFileAssociations;
    property Prerequisites: TStringList read FPrerequisites;
    property Features: TStringList read FFeatures;
  end;

implementation

constructor TWipProject.Create;
begin
  inherited Create;
  FFiles := TStringList.Create;
  FShortcuts := TStringList.Create;
  FRegistryEntries := TStringList.Create;
  FEnvironmentVariables := TStringList.Create;
  FPathEntries := TStringList.Create;
  FFileAssociations := TStringList.Create;
  FPrerequisites := TStringList.Create;
  FFeatures := TStringList.Create;
  Clear;
end;

destructor TWipProject.Destroy;
begin
  FEnvironmentVariables.Free;
  FPathEntries.Free;
  FFileAssociations.Free;
  FPrerequisites.Free;
  FFeatures.Free;
  FRegistryEntries.Free;
  FShortcuts.Free;
  FFiles.Free;
  inherited Destroy;
end;

procedure TWipProject.Clear;
begin
  FProductName := 'Untitled Product';
  FPublisher := 'Unknown Publisher';
  FVersion := '1.0.0';
  FInstallFolder := '{localappdata}\Programs\Untitled Product';
  FLicenseText := '';
  FSigningEnabled := False;
  FSignToolPath := 'signtool.exe';
  FSigningCertificatePath := '';
  FTimestampUrl := 'http://timestamp.digicert.com';
  FFiles.Clear;
  FShortcuts.Clear;
  FRegistryEntries.Clear;
  FEnvironmentVariables.Clear;
  FPathEntries.Clear;
  FFileAssociations.Clear;
  FPrerequisites.Clear;
  FFeatures.Clear;
end;

procedure TWipProject.LoadFromFile(const AFileName: string);
var
  Root: TJSONObject;
  JsonText: TStringList;
  FileArray: TJSONArray;
  ShortcutArray: TJSONArray;
  RegistryArray: TJSONArray;
  EnvironmentArray: TJSONArray;
  PathArray: TJSONArray;
  AssociationArray: TJSONArray;
  PrerequisiteArray: TJSONArray;
  FeatureArray: TJSONArray;
  I: Integer;
  function FindValue(const AName: string): TJSONValue;
  var
    PairIndex: Integer;
    Pair: TJSONPair;
  begin
    Result := nil;
    for PairIndex := 0 to Root.Count - 1 do
    begin
      Pair := Root.Pairs[PairIndex];
      if (Pair <> nil) and (Pair.JsonString <> nil) and SameText(Pair.JsonString.Value, AName) then
      begin
        Result := Pair.JsonValue;
        Exit;
      end;
    end;
  end;
  function ReadArray(const AName: string): TJSONArray;
  var
    Value: TJSONValue;
  begin
    Value := FindValue(AName);
    if Value is TJSONArray then
      Result := TJSONArray(Value)
    else
      Result := nil;
  end;
  function ReadString(const AName, ADefault: string): string;
  var
    Value: TJSONValue;
  begin
    Value := FindValue(AName);
    if Value <> nil then
      Result := Value.Value
    else
      Result := ADefault;
  end;
  function ReadBoolean(const AName: string; const ADefault: Boolean): Boolean;
  var
    Value: TJSONValue;
  begin
    Value := FindValue(AName);
    if Value <> nil then
      Result := SameText(Value.Value, 'true')
    else
      Result := ADefault;
  end;
begin
  JsonText := TStringList.Create;
  try
    JsonText.LoadFromFile(AFileName, TEncoding.UTF8);
    Root := TJSONObject.ParseJSONValue(JsonText.Text) as TJSONObject;
    if Root = nil then
      raise EConvertError.CreateFmt('Invalid Package Studio Pro project: %s', [AFileName]);
    try
      Clear;
      FProductName := ReadString('productName', FProductName);
      FPublisher := ReadString('publisher', FPublisher);
      FVersion := ReadString('version', FVersion);
      FInstallFolder := ReadString('installFolder', FInstallFolder);
      FLicenseText := ReadString('licenseText', FLicenseText);
      FSigningEnabled := ReadBoolean('signingEnabled', FSigningEnabled);
      FSignToolPath := ReadString('signToolPath', FSignToolPath);
      FSigningCertificatePath := ReadString('signingCertificatePath', FSigningCertificatePath);
      FTimestampUrl := ReadString('timestampUrl', FTimestampUrl);
      FileArray := ReadArray('files');
      if FileArray <> nil then
        for I := 0 to FileArray.Count - 1 do
          FFiles.Add(FileArray.Items[I].Value);
      ShortcutArray := ReadArray('shortcuts');
      if ShortcutArray <> nil then
        for I := 0 to ShortcutArray.Count - 1 do
          FShortcuts.Add(ShortcutArray.Items[I].Value);
      RegistryArray := ReadArray('registry');
      if RegistryArray <> nil then
        for I := 0 to RegistryArray.Count - 1 do
          FRegistryEntries.Add(RegistryArray.Items[I].Value);
      EnvironmentArray := ReadArray('environment');
      if EnvironmentArray <> nil then
        for I := 0 to EnvironmentArray.Count - 1 do
          FEnvironmentVariables.Add(EnvironmentArray.Items[I].Value);
      PathArray := ReadArray('pathEntries');
      if PathArray <> nil then
        for I := 0 to PathArray.Count - 1 do
          FPathEntries.Add(PathArray.Items[I].Value);
      AssociationArray := ReadArray('fileAssociations');
      if AssociationArray <> nil then
        for I := 0 to AssociationArray.Count - 1 do
          FFileAssociations.Add(AssociationArray.Items[I].Value);
      PrerequisiteArray := ReadArray('prerequisites');
      if PrerequisiteArray <> nil then
        for I := 0 to PrerequisiteArray.Count - 1 do
          FPrerequisites.Add(PrerequisiteArray.Items[I].Value);
      FeatureArray := ReadArray('features');
      if FeatureArray <> nil then
        for I := 0 to FeatureArray.Count - 1 do
          FFeatures.Add(FeatureArray.Items[I].Value);
    finally
      Root.Free;
    end;
  finally
    JsonText.Free;
  end;
end;

procedure TWipProject.SaveToFile(const AFileName: string);
var
  Root: TJSONObject;
  FileArray: TJSONArray;
  ShortcutArray: TJSONArray;
  RegistryArray: TJSONArray;
  EnvironmentArray: TJSONArray;
  PathArray: TJSONArray;
  AssociationArray: TJSONArray;
  PrerequisiteArray: TJSONArray;
  FeatureArray: TJSONArray;
  JsonText: TStringList;
  I: Integer;
begin
  Root := TJSONObject.Create;
  try
    Root.AddPair('schema', 'PackageStudioPro.Project.v1');
    Root.AddPair('productName', FProductName);
    Root.AddPair('publisher', FPublisher);
    Root.AddPair('version', FVersion);
    Root.AddPair('installFolder', FInstallFolder);
    Root.AddPair('licenseText', FLicenseText);
    Root.AddPair('signingEnabled', TJSONBool.Create(FSigningEnabled));
    Root.AddPair('signToolPath', FSignToolPath);
    Root.AddPair('signingCertificatePath', FSigningCertificatePath);
    Root.AddPair('timestampUrl', FTimestampUrl);
    FileArray := TJSONArray.Create;
    for I := 0 to FFiles.Count - 1 do
      FileArray.Add(FFiles[I]);
    Root.AddPair('files', FileArray);
    ShortcutArray := TJSONArray.Create;
    for I := 0 to FShortcuts.Count - 1 do
      ShortcutArray.Add(FShortcuts[I]);
    Root.AddPair('shortcuts', ShortcutArray);
    RegistryArray := TJSONArray.Create;
    for I := 0 to FRegistryEntries.Count - 1 do
      RegistryArray.Add(FRegistryEntries[I]);
    Root.AddPair('registry', RegistryArray);
    EnvironmentArray := TJSONArray.Create;
    for I := 0 to FEnvironmentVariables.Count - 1 do
      EnvironmentArray.Add(FEnvironmentVariables[I]);
    Root.AddPair('environment', EnvironmentArray);
    PathArray := TJSONArray.Create;
    for I := 0 to FPathEntries.Count - 1 do
      PathArray.Add(FPathEntries[I]);
    Root.AddPair('pathEntries', PathArray);
    AssociationArray := TJSONArray.Create;
    for I := 0 to FFileAssociations.Count - 1 do
      AssociationArray.Add(FFileAssociations[I]);
    Root.AddPair('fileAssociations', AssociationArray);
    PrerequisiteArray := TJSONArray.Create;
    for I := 0 to FPrerequisites.Count - 1 do
      PrerequisiteArray.Add(FPrerequisites[I]);
    Root.AddPair('prerequisites', PrerequisiteArray);
    FeatureArray := TJSONArray.Create;
    for I := 0 to FFeatures.Count - 1 do
      FeatureArray.Add(FFeatures[I]);
    Root.AddPair('features', FeatureArray);

    ForceDirectories(ExtractFilePath(AFileName));
    JsonText := TStringList.Create;
    try
      JsonText.Text := Root.Format(2);
      JsonText.SaveToFile(AFileName, TEncoding.UTF8);
    finally
      JsonText.Free;
    end;
  finally
    Root.Free;
  end;
end;

function TWipProject.Validate(out AMessage: string): Boolean;
begin
  Result := False;
  if Trim(FProductName) = '' then
    AMessage := 'Product name is required.'
  else if Trim(FVersion) = '' then
    AMessage := 'Version is required.'
  else if Trim(FInstallFolder) = '' then
    AMessage := 'Install folder is required.'
  else
  begin
    AMessage := 'Project is valid.';
    Result := True;
  end;
end;

end.

