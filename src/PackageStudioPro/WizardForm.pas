unit WizardForm;

interface

uses
  System.Classes, System.IOUtils, System.SysUtils, System.Types, System.UITypes,
  FMX.Controls, FMX.Dialogs, FMX.Edit, FMX.Forms, FMX.Layouts, FMX.ListBox,
  FMX.Memo, FMX.Objects, FMX.StdCtrls, FMX.Types, Winapi.Windows,
  Winapi.ShellAPI, Wip.Project, Wip.Safety, FMX.Memo.Types, FMX.ScrollBox,
  FMX.Controls.Presentation, FMX.TabControl;

type
  TSetupBuildWizardForm = class(TForm)
    RootLayout: TLayout;
    HeaderPanel: TRectangle;
    BrandIcon: TRectangle;
    BrandWindow: TRectangle;
    BrandPane1: TRectangle;
    BrandPane2: TRectangle;
    BrandPane3: TRectangle;
    BrandPane4: TRectangle;
    BrandDial: TRectangle;
    BrandArrowLabel: TLabel;
    TitleLabel: TLabel;
    SubtitleLabel: TLabel;
    HeaderPurposeLabel: TLabel;
    ContentScroll: TScrollBox;
    MainTabs: TTabControl;
    ProductTab: TTabItem;
    ProductScroll: TScrollBox;
    ProductPage: TLayout;
    PayloadTab: TTabItem;
    PayloadScroll: TScrollBox;
    PayloadPage: TLayout;
    InstallTab: TTabItem;
    InstallScroll: TScrollBox;
    InstallPage: TLayout;
    IntegrationTab: TTabItem;
    IntegrationScroll: TScrollBox;
    IntegrationPage: TLayout;
    BuildReviewTab: TTabItem;
    BuildReviewScroll: TScrollBox;
    BuildReviewPage: TLayout;
    ProjectSourceLabel: TLabel;
    ProjectSourceEdit: TEdit;
    BrowseSourceButton: TButton;
    AppExeLabel: TLabel;
    AppExeEdit: TEdit;
    BrowseAppButton: TButton;
    PayloadLabel: TLabel;
    PayloadPathEdit: TEdit;
    BrowsePayloadButton: TButton;
    AddPayloadButton: TButton;
    RemovePayloadButton: TButton;
    PayloadList: TListBox;
    ProductNameLabel: TLabel;
    ProductNameEdit: TEdit;
    PublisherLabel: TLabel;
    PublisherEdit: TEdit;
    VersionLabel: TLabel;
    VersionEdit: TEdit;
    InstallModeLabel: TLabel;
    CurrentUserRadio: TRadioButton;
    ProgramFilesRadio: TRadioButton;
    InstallFolderLabel: TLabel;
    InstallFolderEdit: TEdit;
    BrowseInstallButton: TButton;
    ShortcutLabel: TLabel;
    StartMenuCheckBox: TCheckBox;
    DesktopCheckBox: TCheckBox;
    ProjectFileLabel: TLabel;
    ProjectFileEdit: TEdit;
    NewProjectButton: TButton;
    BrowseProjectButton: TButton;
    OpenProjectButton: TButton;
    OutputFolderLabel: TLabel;
    OutputFolderEdit: TEdit;
    BrowseOutputButton: TButton;
    LicenseLabel: TLabel;
    LicenseMemo: TMemo;
    EnvironmentLabel: TLabel;
    EnvironmentNameEdit: TEdit;
    EnvironmentValueEdit: TEdit;
    AddEnvironmentButton: TButton;
    EnvironmentList: TListBox;
    RemoveEnvironmentButton: TButton;
    PathEntryLabel: TLabel;
    PathEntryEdit: TEdit;
    AddPathEntryButton: TButton;
    RemovePathEntryButton: TButton;
    PathEntryList: TListBox;
    AssociationLabel: TLabel;
    AssociationExtensionEdit: TEdit;
    AssociationDescriptionEdit: TEdit;
    AssociationTargetEdit: TEdit;
    BrowseAssociationTargetButton: TButton;
    AddAssociationButton: TButton;
    AssociationList: TListBox;
    RemoveAssociationButton: TButton;
    RegistryLabel: TLabel;
    RegistryKeyEdit: TEdit;
    RegistryNameEdit: TEdit;
    RegistryValueEdit: TEdit;
    AddRegistryButton: TButton;
    RegistryList: TListBox;
    RemoveRegistryButton: TButton;
    AssociationListLabel: TLabel;
    ReviewLabel: TLabel;
    LogLabel: TLabel;
    ReviewMemo: TMemo;
    LogMemo: TMemo;
    FooterPanel: TRectangle;
    FooterBrandIcon: TRectangle;
    FooterBrandWindow: TRectangle;
    FooterBrandPane1: TRectangle;
    FooterBrandPane2: TRectangle;
    FooterBrandPane3: TRectangle;
    FooterBrandPane4: TRectangle;
    FooterBrandDial: TRectangle;
    FooterBrandArrowLabel: TLabel;
    FooterBrandLabel: TLabel;
    BuildButton: TButton;
    ValidateButton: TButton;
    CloseButton: TButton;
    Label1: TLabel;
    UserHelpButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure BrowseSourceButtonClick(Sender: TObject);
    procedure BrowseAppButtonClick(Sender: TObject);
    procedure BrowsePayloadButtonClick(Sender: TObject);
    procedure AddPayloadFolderButtonClick(Sender: TObject);
    procedure RemovePayloadButtonClick(Sender: TObject);
    procedure BrowseInstallButtonClick(Sender: TObject);
    procedure NewProjectButtonClick(Sender: TObject);
    procedure BrowseProjectButtonClick(Sender: TObject);
    procedure OpenProjectButtonClick(Sender: TObject);
    procedure BrowseOutputButtonClick(Sender: TObject);
    procedure BrowseAssociationTargetButtonClick(Sender: TObject);
    procedure ProductNameEditChangeTracking(Sender: TObject);
    procedure CurrentUserRadioChange(Sender: TObject);
    procedure ProgramFilesRadioChange(Sender: TObject);
    procedure StartMenuCheckBoxChange(Sender: TObject);
    procedure DesktopCheckBoxChange(Sender: TObject);
    procedure AddEnvironmentButtonClick(Sender: TObject);
    procedure RemoveEnvironmentButtonClick(Sender: TObject);
    procedure AddPathEntryButtonClick(Sender: TObject);
    procedure RemovePathEntryButtonClick(Sender: TObject);
    procedure AddAssociationButtonClick(Sender: TObject);
    procedure RemoveAssociationButtonClick(Sender: TObject);
    procedure AddRegistryButtonClick(Sender: TObject);
    procedure RemoveRegistryButtonClick(Sender: TObject);
    procedure MainTabsChange(Sender: TObject);
    procedure ValidateButtonClick(Sender: TObject);
    procedure UserHelpButtonClick(Sender: TObject);
    procedure BuildButtonClick(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
  private
    FProject: TWipProject;
    FPathEntryEdit: TEdit;
    FPathEntryList: TListBox;
    FAddPathEntryButton: TButton;
    FRemovePathEntryButton: TButton;
    FAutoPathsEnabled: Boolean;
    FLoadingProject: Boolean;
    FUpdatingInstallMode: Boolean;
    function BuilderFileName: string;
    function CurrentUserInstallRoot: string;
    function DefaultInstallFolder(const AUnderProgramFiles: Boolean): string;
    function ProductToken: string;
    function ProductTitleFromFileName(const AFileName: string): string;
    function ProgramFilesInstallRoot: string;
    function SafeFileName(const AValue: string): string;
    function SettingsFileName: string;
    function SetupProjectFolder: string;
    function ExportRootFolder: string;
    procedure AddListItem(AList: TListBox; const AText: string);
    procedure ApplyProjectSourceFile(const AFileName: string);
    procedure AutoFillFromExe(const AExeFile: string);
    procedure BrowseDirectoryInto(AEdit: TEdit; const ATitle: string);
    procedure BrowseFileInto(AEdit: TEdit; const ATitle, AFilter: string);
    procedure BrowseProjectFileInto(AEdit: TEdit);
    procedure AddPayloadFile(const AFileName: string);
    procedure AddPayloadFolder(const AFolderName: string);
    procedure LoadProjectFileIntoFields(const AFileName: string);
    procedure LoadFieldsToProject;
    procedure Log(const AMessage: string);
    procedure NewProject;
    procedure OpenHelpFile(const AHelpFileName: string);
    procedure BuildTabbedWorkspace;
    procedure RefreshBuildActions;
    procedure SaveProject;
    procedure SaveLastProjectFile(const AFileName: string);
    procedure RefreshAutoPaths;
    procedure RefreshInstallFolder;
    procedure RefreshLists;
    procedure RefreshReview;
    procedure RunBuild;
    procedure SelectInstallMode(const AUnderProgramFiles, AUpdateFolder: Boolean);
    function ValidateForBuild: Boolean;
  public
    destructor Destroy; override;
  end;

var
  SetupBuildWizardForm: TSetupBuildWizardForm;

implementation

{$R *.fmx}

procedure TSetupBuildWizardForm.FormCreate(Sender: TObject);
begin
  WindowState := TWindowState.wsNormal;
  Width := 1220;
  Height := 760;
  Position := TFormPosition.ScreenCenter;
  FProject := TWipProject.Create;
  FAutoPathsEnabled := True;
  FLoadingProject := False;
  FUpdatingInstallMode := False;
  BuildTabbedWorkspace;
  SelectInstallMode(True, True);
  StartMenuCheckBox.IsChecked := True;
  DesktopCheckBox.IsChecked := False;
  ProductNameEdit.Text := '';
  PublisherEdit.Text := 'Unknown Publisher';
  VersionEdit.Text := '1.0.0';
  RefreshInstallFolder;
  RefreshAutoPaths;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.NewProject;
begin
  FProject.Clear;
  FAutoPathsEnabled := True;
  ProjectSourceEdit.Text := '';
  AppExeEdit.Text := '';
  PayloadPathEdit.Text := '';
  PayloadList.Items.Clear;
  ProductNameEdit.Text := '';
  PublisherEdit.Text := 'Unknown Publisher';
  VersionEdit.Text := '1.0.0';
  SelectInstallMode(True, True);
  StartMenuCheckBox.IsChecked := True;
  DesktopCheckBox.IsChecked := False;
  LicenseMemo.Lines.Clear;
  EnvironmentNameEdit.Text := '';
  EnvironmentValueEdit.Text := '';
  if FPathEntryEdit <> nil then
    FPathEntryEdit.Text := '';
  AssociationExtensionEdit.Text := '';
  AssociationDescriptionEdit.Text := '';
  AssociationTargetEdit.Text := '';
  RegistryKeyEdit.Text := '';
  RegistryNameEdit.Text := '';
  RegistryValueEdit.Text := '';
  RefreshLists;
  RefreshAutoPaths;
  LogMemo.Lines.Clear;
  RefreshReview;
  Log('New project ready.');
end;

procedure TSetupBuildWizardForm.SaveProject;
begin
  if Trim(ProjectFileEdit.Text) = '' then
  begin
    BrowseProjectFileInto(ProjectFileEdit);
    if Trim(ProjectFileEdit.Text) = '' then
      Exit;
  end;

  ForceDirectories(ExtractFilePath(ProjectFileEdit.Text));
  LoadFieldsToProject;
  FProject.SaveToFile(ProjectFileEdit.Text);
  SaveLastProjectFile(ProjectFileEdit.Text);
  FAutoPathsEnabled := False;
  RefreshReview;
  Log('Saved project: ' + ProjectFileEdit.Text);
end;

destructor TSetupBuildWizardForm.Destroy;
begin
  FProject.Free;
  inherited;
end;

procedure TSetupBuildWizardForm.BuildTabbedWorkspace;

  procedure StyleTree(AObject: TFmxObject);
  var
    I: Integer;
    Control: TControl;
    Edit: TEdit;
    Memo: TMemo;
    LabelControl: TLabel;
    Button: TButton;
    CheckBox: TCheckBox;
    Radio: TRadioButton;
  begin
    if AObject is TControl then
    begin
      Control := TControl(AObject);
      if Control is TEdit then
      begin
        Edit := TEdit(Control);
        Edit.StyledSettings := Edit.StyledSettings - [TStyledSetting.Size];
        Edit.TextSettings.Font.Size := 12.5;
      end
      else if Control is TMemo then
      begin
        Memo := TMemo(Control);
        Memo.StyledSettings := Memo.StyledSettings - [TStyledSetting.Size];
        Memo.TextSettings.Font.Size := 12.5;
      end
      else if Control is TCheckBox then
      begin
        CheckBox := TCheckBox(Control);
        CheckBox.StyledSettings := CheckBox.StyledSettings - [TStyledSetting.Size];
        CheckBox.TextSettings.Font.Size := 12.5;
      end
      else if Control is TRadioButton then
      begin
        Radio := TRadioButton(Control);
        Radio.StyledSettings := Radio.StyledSettings - [TStyledSetting.Size];
        Radio.TextSettings.Font.Size := 12.5;
      end
      else if Control is TButton then
      begin
        Button := TButton(Control);
        Button.StyledSettings := Button.StyledSettings - [TStyledSetting.Size];
        Button.TextSettings.Font.Size := 12;
      end
      else if Control is TLabel then
      begin
        LabelControl := TLabel(Control);
        LabelControl.StyledSettings := LabelControl.StyledSettings - [TStyledSetting.Size];
        if LabelControl.TextSettings.Font.Size < 12 then
          LabelControl.TextSettings.Font.Size := 12;
      end;
    end;

    for I := 0 to AObject.ChildrenCount - 1 do
      StyleTree(AObject.Children[I]);
  end;

begin
  FPathEntryEdit := PathEntryEdit;
  FPathEntryList := PathEntryList;
  FAddPathEntryButton := AddPathEntryButton;
  FRemovePathEntryButton := RemovePathEntryButton;

  HeaderPurposeLabel.Visible := False;
  if MainTabs <> nil then
    MainTabs.ActiveTab := ProductTab;

  StyleTree(Self);
  RefreshBuildActions;
end;

procedure TSetupBuildWizardForm.RefreshBuildActions;
var
  OnBuildReview: Boolean;
begin
  OnBuildReview := (MainTabs <> nil) and (MainTabs.ActiveTab = BuildReviewTab);
  ValidateButton.Visible := OnBuildReview;
  BuildButton.Visible := OnBuildReview;
end;

function TSetupBuildWizardForm.BuilderFileName: string;
var
  AppFolder: string;
  Candidate: string;
begin
  AppFolder := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)));
  Candidate := AppFolder + 'WIPBuild.exe';
  if FileExists(Candidate) then
    Exit(Candidate);
  Candidate := ExpandFileName(AppFolder + '..\..\bin\WIPBuild.exe');
  if FileExists(Candidate) then
    Exit(Candidate);
  Candidate := ExpandFileName(AppFolder + '..\bin\WIPBuild.exe');
  if FileExists(Candidate) then
    Exit(Candidate);
  Result := AppFolder + 'WIPBuild.exe';
end;

function TSetupBuildWizardForm.SetupProjectFolder: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\MySetups');
end;

function TSetupBuildWizardForm.ExportRootFolder: string;
begin
  Result := ExpandFileName(ExtractFilePath(ParamStr(0)) + '..\Exports');
end;

function TSetupBuildWizardForm.SettingsFileName: string;
begin
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA')) +
    'PackageStudioPro\settings.txt';
end;

procedure TSetupBuildWizardForm.SaveLastProjectFile(const AFileName: string);
begin
  ForceDirectories(ExtractFilePath(SettingsFileName));
  TFile.WriteAllText(SettingsFileName, ExtractFilePath(AFileName), TEncoding.UTF8);
end;

function TSetupBuildWizardForm.SafeFileName(const AValue: string): string;
var
  Ch: Char;
begin
  Result := Trim(AValue);
  for Ch in ['\', '/', ':', '*', '?', '"', '<', '>', '|'] do
    Result := StringReplace(Result, Ch, '_', [rfReplaceAll]);
  Result := StringReplace(Result, ' ', '', [rfReplaceAll]);
  if Result = '' then
    Result := 'SetupProject';
end;

function TSetupBuildWizardForm.ProductToken: string;
begin
  Result := SafeFileName(ProductNameEdit.Text);
end;

function TSetupBuildWizardForm.CurrentUserInstallRoot: string;
begin
  Result := IncludeTrailingPathDelimiter(GetEnvironmentVariable('LOCALAPPDATA')) + 'Programs';
end;

function TSetupBuildWizardForm.ProgramFilesInstallRoot: string;
begin
  Result := GetEnvironmentVariable('ProgramFiles');
  if Result = '' then
    Result := GetEnvironmentVariable('ProgramFiles(x86)');
  if Result = '' then
    Result := 'C:\Program Files';
end;

function TSetupBuildWizardForm.DefaultInstallFolder(const AUnderProgramFiles: Boolean): string;
var
  ProductFolder: string;
begin
  ProductFolder := Trim(ProductNameEdit.Text);
  if ProductFolder = '' then
    ProductFolder := 'My Application';
  if AUnderProgramFiles then
    Result := IncludeTrailingPathDelimiter(ProgramFilesInstallRoot) + ProductFolder
  else
    Result := IncludeTrailingPathDelimiter(CurrentUserInstallRoot) + ProductFolder;
end;

function TSetupBuildWizardForm.ProductTitleFromFileName(const AFileName: string): string;
var
  BaseName: string;
  I: Integer;
begin
  BaseName := ChangeFileExt(ExtractFileName(AFileName), '');
  BaseName := StringReplace(BaseName, '_', ' ', [rfReplaceAll]);
  BaseName := StringReplace(BaseName, '-', ' ', [rfReplaceAll]);
  Result := '';
  for I := 1 to Length(BaseName) do
  begin
    if (I > 1) and CharInSet(BaseName[I], ['A'..'Z']) and
      (CharInSet(BaseName[I - 1], ['a'..'z', '0'..'9']) or
      ((I < Length(BaseName)) and CharInSet(BaseName[I - 1], ['A'..'Z']) and CharInSet(BaseName[I + 1], ['a'..'z']))) then
      Result := Result + ' ';
    Result := Result + BaseName[I];
  end;
  if Trim(Result) = '' then
    Result := 'My Application';
end;

procedure TSetupBuildWizardForm.AddListItem(AList: TListBox; const AText: string);
begin
  AList.Items.Add(AText);
end;

procedure TSetupBuildWizardForm.RefreshLists;
var
  I: Integer;
begin
  EnvironmentList.Items.Clear;
  for I := 0 to FProject.EnvironmentVariables.Count - 1 do
    AddListItem(EnvironmentList, FProject.EnvironmentVariables[I]);
  if FPathEntryList <> nil then
  begin
    FPathEntryList.Items.Clear;
    for I := 0 to FProject.PathEntries.Count - 1 do
      AddListItem(FPathEntryList, FProject.PathEntries[I]);
  end;
  AssociationList.Items.Clear;
  for I := 0 to FProject.FileAssociations.Count - 1 do
    AddListItem(AssociationList, FProject.FileAssociations[I]);
  RegistryList.Items.Clear;
  for I := 0 to FProject.RegistryEntries.Count - 1 do
    AddListItem(RegistryList, FProject.RegistryEntries[I]);
end;

procedure TSetupBuildWizardForm.RefreshAutoPaths;
begin
  if not FAutoPathsEnabled then
    Exit;
  ForceDirectories(SetupProjectFolder);
  ForceDirectories(ExportRootFolder);
  ProjectFileEdit.Text := IncludeTrailingPathDelimiter(SetupProjectFolder) + ProductToken + 'Setup.wiproj';
  OutputFolderEdit.Text := IncludeTrailingPathDelimiter(ExportRootFolder) + ProductToken;
end;

procedure TSetupBuildWizardForm.RefreshInstallFolder;
begin
  InstallFolderEdit.Text := DefaultInstallFolder(ProgramFilesRadio.IsChecked);
end;

procedure TSetupBuildWizardForm.SelectInstallMode(const AUnderProgramFiles, AUpdateFolder: Boolean);
begin
  if FUpdatingInstallMode then
    Exit;
  FUpdatingInstallMode := True;
  try
    ProgramFilesRadio.IsChecked := AUnderProgramFiles;
    CurrentUserRadio.IsChecked := not AUnderProgramFiles;
    if AUpdateFolder then
      InstallFolderEdit.Text := DefaultInstallFolder(AUnderProgramFiles);
  finally
    FUpdatingInstallMode := False;
  end;
end;

procedure TSetupBuildWizardForm.ApplyProjectSourceFile(const AFileName: string);
var
  BaseName: string;
  SourceFolder: string;
  CandidateExe: string;
begin
  if Trim(AFileName) = '' then
    Exit;
  ProjectSourceEdit.Text := AFileName;
  BaseName := ChangeFileExt(ExtractFileName(AFileName), '');
  SourceFolder := ExtractFilePath(AFileName);
  ProductNameEdit.Text := ProductTitleFromFileName(AFileName);
  CandidateExe := IncludeTrailingPathDelimiter(SourceFolder) + BaseName + '.exe';
  if FileExists(CandidateExe) then
    AppExeEdit.Text := CandidateExe;
  if Trim(PublisherEdit.Text) = '' then
    PublisherEdit.Text := 'Unknown Publisher';
  if Trim(VersionEdit.Text) = '' then
    VersionEdit.Text := '1.0.0';
  ProjectFileEdit.Text := IncludeTrailingPathDelimiter(SourceFolder) + BaseName + '.wiproj';
  OutputFolderEdit.Text := IncludeTrailingPathDelimiter(SourceFolder) + 'InstallerOutput';
  FAutoPathsEnabled := False;
  RefreshInstallFolder;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.AddPayloadFile(const AFileName: string);
var
  FullName: string;
begin
  FullName := Trim(AFileName);
  if FullName = '' then
    Exit;
  if PayloadList.Items.IndexOf(FullName) < 0 then
    PayloadList.Items.Add(FullName);
  PayloadPathEdit.Text := '';
  RefreshReview;
end;

procedure TSetupBuildWizardForm.AddPayloadFolder(const AFolderName: string);
var
  FullFolder: string;
  FileName: string;
begin
  FullFolder := Trim(AFolderName);
  if (FullFolder = '') or not TDirectory.Exists(FullFolder) then
    Exit;
  for FileName in TDirectory.GetFiles(FullFolder, '*', TSearchOption.soAllDirectories) do
    AddPayloadFile(FileName);
  PayloadPathEdit.Text := FullFolder;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.LoadFieldsToProject;
var
  I: Integer;
begin
  FProject.ProductName := ProductNameEdit.Text;
  FProject.Publisher := PublisherEdit.Text;
  FProject.Version := VersionEdit.Text;
  FProject.InstallFolder := InstallFolderEdit.Text;
  FProject.LicenseText := LicenseMemo.Lines.Text;
  FProject.Files.Clear;
  if Trim(AppExeEdit.Text) <> '' then
    FProject.Files.Add(AppExeEdit.Text);
  for I := 0 to PayloadList.Items.Count - 1 do
    if (Trim(PayloadList.Items[I]) <> '') and (FProject.Files.IndexOf(PayloadList.Items[I]) < 0) then
      FProject.Files.Add(PayloadList.Items[I]);
  // Retain additional project shortcuts (for example an installed user guide).
  // The two checkboxes control their locations and the primary app shortcut.
  for I := FProject.Shortcuts.Count - 1 downto 0 do
    if (FProject.Shortcuts[I].StartsWith('StartMenu|', True) and
        (not StartMenuCheckBox.IsChecked or FProject.Shortcuts[I].EndsWith('|' + ExtractFileName(AppExeEdit.Text), True))) or
       (FProject.Shortcuts[I].StartsWith('Desktop|', True) and
        (not DesktopCheckBox.IsChecked or FProject.Shortcuts[I].EndsWith('|' + ExtractFileName(AppExeEdit.Text), True))) then
      FProject.Shortcuts.Delete(I);
  if (Trim(AppExeEdit.Text) <> '') and StartMenuCheckBox.IsChecked then
    FProject.Shortcuts.Add('StartMenu|' + ProductNameEdit.Text + '|' + ExtractFileName(AppExeEdit.Text));
  if (Trim(AppExeEdit.Text) <> '') and DesktopCheckBox.IsChecked then
    FProject.Shortcuts.Add('Desktop|' + ProductNameEdit.Text + '|' + ExtractFileName(AppExeEdit.Text));
end;

procedure TSetupBuildWizardForm.RefreshReview;
begin
  if FLoadingProject then
    Exit;
  LoadFieldsToProject;
  ReviewMemo.Lines.BeginUpdate;
  try
    ReviewMemo.Lines.Clear;
    ReviewMemo.Lines.Add('Project source: ' + ProjectSourceEdit.Text);
    ReviewMemo.Lines.Add('Application EXE: ' + AppExeEdit.Text);
    ReviewMemo.Lines.Add('Product: ' + FProject.ProductName);
    ReviewMemo.Lines.Add('Publisher: ' + FProject.Publisher);
    ReviewMemo.Lines.Add('Version: ' + FProject.Version);
    ReviewMemo.Lines.Add('Install folder: ' + FProject.InstallFolder);
    ReviewMemo.Lines.Add('Authoring save file: ' + ProjectFileEdit.Text);
    ReviewMemo.Lines.Add('Build output folder: ' + OutputFolderEdit.Text);
    ReviewMemo.Lines.Add('');
    ReviewMemo.Lines.Add('Payload files: ' + FProject.Files.Count.ToString);
    ReviewMemo.Lines.Add('Shortcuts: ' + FProject.Shortcuts.Count.ToString);
    ReviewMemo.Lines.Add('Environment variables: ' + FProject.EnvironmentVariables.Count.ToString);
    ReviewMemo.Lines.Add('PATH entries: ' + FProject.PathEntries.Count.ToString);
    ReviewMemo.Lines.Add('File associations: ' + FProject.FileAssociations.Count.ToString);
    ReviewMemo.Lines.Add('Registry entries: ' + FProject.RegistryEntries.Count.ToString);
    if ProgramFilesRadio.IsChecked then
      ReviewMemo.Lines.Add('Admin note: Program Files installs normally require running the package as administrator.');
  finally
    ReviewMemo.Lines.EndUpdate;
  end;
end;

procedure TSetupBuildWizardForm.AutoFillFromExe(const AExeFile: string);
begin
  AppExeEdit.Text := AExeFile;
  if Trim(ProductNameEdit.Text) = '' then
    ProductNameEdit.Text := ProductTitleFromFileName(AExeFile);
  if Trim(PublisherEdit.Text) = '' then
    PublisherEdit.Text := 'Unknown Publisher';
  if Trim(VersionEdit.Text) = '' then
    VersionEdit.Text := '1.0.0';
  RefreshInstallFolder;
  RefreshAutoPaths;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.BrowseDirectoryInto(AEdit: TEdit; const ATitle: string);
var
  Directory: string;
begin
  Directory := Trim(AEdit.Text);
  if (Directory = '') or not TDirectory.Exists(Directory) then
    Directory := GetEnvironmentVariable('USERPROFILE');
  if SelectDirectory(ATitle, '', Directory) then
  begin
    AEdit.Text := Directory;
    if AEdit = OutputFolderEdit then
      FAutoPathsEnabled := False;
    RefreshReview;
  end;
end;

procedure TSetupBuildWizardForm.BrowseFileInto(AEdit: TEdit; const ATitle, AFilter: string);
var
  Dialog: TOpenDialog;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Title := ATitle;
    Dialog.Filter := AFilter;
    if Trim(AEdit.Text) <> '' then
    begin
      if TFile.Exists(AEdit.Text) then
        Dialog.FileName := AEdit.Text
      else if TDirectory.Exists(ExtractFilePath(AEdit.Text)) then
        Dialog.InitialDir := ExtractFilePath(AEdit.Text);
    end;
    if Dialog.Execute then
    begin
      AEdit.Text := Dialog.FileName;
      if AEdit = ProjectFileEdit then
        FAutoPathsEnabled := False;
      RefreshReview;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TSetupBuildWizardForm.BrowseProjectFileInto(AEdit: TEdit);
var
  Dialog: TSaveDialog;
begin
  Dialog := TSaveDialog.Create(nil);
  try
    Dialog.Title := 'Choose installer project save file';
    Dialog.Filter := 'Package Studio Pro projects (*.wiproj)|*.wiproj|All files (*.*)|*.*';
    Dialog.DefaultExt := 'wiproj';
    if Trim(AEdit.Text) <> '' then
    begin
      Dialog.FileName := ExtractFileName(AEdit.Text);
      if TDirectory.Exists(ExtractFilePath(AEdit.Text)) then
        Dialog.InitialDir := ExtractFilePath(AEdit.Text);
    end;
    if Dialog.Execute then
    begin
      AEdit.Text := Dialog.FileName;
      FAutoPathsEnabled := False;
      RefreshReview;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TSetupBuildWizardForm.Log(const AMessage: string);
begin
  if Trim(AMessage) <> '' then
    LogMemo.Lines.Add(Trim(AMessage));
end;

function TSetupBuildWizardForm.ValidateForBuild: Boolean;
var
  Errors: TStringList;
begin
  Result := False;
  LoadFieldsToProject;
  if Trim(AppExeEdit.Text) = '' then
  begin
    Log('Select the application EXE before building.');
    Exit;
  end;
  if Trim(ProductNameEdit.Text) = '' then
  begin
    Log('Product name is required.');
    Exit;
  end;
  Errors := TStringList.Create;
  try
    if not TWipSafety.ValidateProject(FProject, Errors) then
    begin
      Log('Project validation failed:');
      Log(Errors.Text);
      Exit;
    end;
  finally
    Errors.Free;
  end;
  Result := True;
end;

procedure TSetupBuildWizardForm.ValidateButtonClick(Sender: TObject);
begin
  LogMemo.Lines.Clear;
  if ValidateForBuild then
    Log('Validation passed. Ready to build the setup file.');
  RefreshReview;
end;

procedure TSetupBuildWizardForm.MainTabsChange(Sender: TObject);
begin
  RefreshBuildActions;
end;

procedure TSetupBuildWizardForm.RunBuild;
var
  StartupInfo: TStartupInfo;
  ProcessInfo: TProcessInformation;
  ExitCode: Cardinal;
  CommandLine: string;
  LogFile: string;
  BuildOutput: TStringList;
  I: Integer;
begin
  if not ValidateForBuild then
    Exit;
  if not FileExists(BuilderFileName) then
  begin
    Log('Build tool not found: ' + BuilderFileName);
    Exit;
  end;

  ForceDirectories(ExtractFilePath(ProjectFileEdit.Text));
  ForceDirectories(OutputFolderEdit.Text);
  FProject.SaveToFile(ProjectFileEdit.Text);
  LogFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) + 'WIPWizardBuild_' + GetTickCount.ToString + '.log';
  CommandLine := 'cmd.exe /c ""' + BuilderFileName + '" "' + ProjectFileEdit.Text + '" "' + OutputFolderEdit.Text +
    '" > "' + LogFile + '" 2>&1"';
  ZeroMemory(@StartupInfo, SizeOf(StartupInfo));
  StartupInfo.cb := SizeOf(StartupInfo);
  StartupInfo.dwFlags := STARTF_USESHOWWINDOW;
  StartupInfo.wShowWindow := SW_HIDE;
  ZeroMemory(@ProcessInfo, SizeOf(ProcessInfo));

  Log('Starting setup export...');
  if not CreateProcess(nil, PChar(CommandLine), nil, nil, False, CREATE_NO_WINDOW, nil, nil, StartupInfo, ProcessInfo) then
  begin
    Log('Build failed to start. Windows error: ' + GetLastError.ToString);
    Exit;
  end;
  try
    WaitForSingleObject(ProcessInfo.hProcess, INFINITE);
    if FileExists(LogFile) then
    begin
      BuildOutput := TStringList.Create;
      try
        BuildOutput.LoadFromFile(LogFile, TEncoding.Default);
        for I := 0 to BuildOutput.Count - 1 do
          Log(BuildOutput[I]);
      finally
        BuildOutput.Free;
        System.SysUtils.DeleteFile(LogFile);
      end;
    end;
    if GetExitCodeProcess(ProcessInfo.hProcess, ExitCode) and (ExitCode = 0) then
      Log('Setup export completed: ' + OutputFolderEdit.Text)
    else
      Log('Setup export failed. Exit code: ' + ExitCode.ToString);
  finally
    CloseHandle(ProcessInfo.hThread);
    CloseHandle(ProcessInfo.hProcess);
  end;
end;

procedure TSetupBuildWizardForm.BrowseAppButtonClick(Sender: TObject);
begin
  BrowseFileInto(AppExeEdit, 'Select application EXE', 'Executable files (*.exe)|*.exe|All files (*.*)|*.*');
  if TFile.Exists(AppExeEdit.Text) then
    AutoFillFromExe(AppExeEdit.Text);
end;

procedure TSetupBuildWizardForm.LoadProjectFileIntoFields(const AFileName: string);
var
  I: Integer;
  FileName: string;
  AppExe: string;
  Entry: string;
begin
  if not FileExists(AFileName) then
  begin
    Log('Authoring project file not found: ' + AFileName);
    Exit;
  end;

  FLoadingProject := True;
  PayloadList.BeginUpdate;
  LicenseMemo.Lines.BeginUpdate;
  try
    FProject.LoadFromFile(AFileName);
    FAutoPathsEnabled := False;
    ProjectFileEdit.Text := AFileName;
    ProjectSourceEdit.Text := '';
    ProductNameEdit.Text := FProject.ProductName;
    PublisherEdit.Text := FProject.Publisher;
    VersionEdit.Text := FProject.Version;
    OutputFolderEdit.Text := IncludeTrailingPathDelimiter(ExportRootFolder) + ProductToken;
    SelectInstallMode(Pos(UpperCase(IncludeTrailingPathDelimiter(ProgramFilesInstallRoot)),
      UpperCase(IncludeTrailingPathDelimiter(FProject.InstallFolder))) = 1, False);
    InstallFolderEdit.Text := FProject.InstallFolder;
    LicenseMemo.Lines.Text := FProject.LicenseText;

    AppExe := '';
    for I := 0 to FProject.Files.Count - 1 do
    begin
      FileName := FProject.Files[I];
      if SameText(ExtractFileExt(FileName), '.exe') then
      begin
        AppExe := FileName;
        Break;
      end;
    end;
    if (AppExe = '') and (FProject.Files.Count > 0) then
      AppExe := FProject.Files[0];
    AppExeEdit.Text := AppExe;

    PayloadList.Items.Clear;
    for I := 0 to FProject.Files.Count - 1 do
      if not SameText(FProject.Files[I], AppExe) then
        PayloadList.Items.Add(FProject.Files[I]);

    StartMenuCheckBox.IsChecked := False;
    DesktopCheckBox.IsChecked := False;
    for I := 0 to FProject.Shortcuts.Count - 1 do
    begin
      Entry := FProject.Shortcuts[I];
      if SameText(Copy(Entry, 1, Length('StartMenu|')), 'StartMenu|') then
        StartMenuCheckBox.IsChecked := True
      else if SameText(Copy(Entry, 1, Length('Desktop|')), 'Desktop|') then
        DesktopCheckBox.IsChecked := True;
    end;
  finally
    LicenseMemo.Lines.EndUpdate;
    PayloadList.EndUpdate;
    FLoadingProject := False;
  end;

  RefreshLists;
  RefreshReview;
  SaveLastProjectFile(AFileName);
  Log('Loaded authoring project: ' + AFileName);
end;

procedure TSetupBuildWizardForm.BrowsePayloadButtonClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  FileName: string;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Title := 'Select payload or support files';
    Dialog.Filter := 'All files (*.*)|*.*';
    Dialog.Options := Dialog.Options + [TOpenOption.ofAllowMultiSelect, TOpenOption.ofFileMustExist];
    if Trim(PayloadPathEdit.Text) <> '' then
    begin
      if TFile.Exists(PayloadPathEdit.Text) then
        Dialog.FileName := PayloadPathEdit.Text
      else if TDirectory.Exists(PayloadPathEdit.Text) then
        Dialog.InitialDir := PayloadPathEdit.Text
      else if TDirectory.Exists(ExtractFilePath(PayloadPathEdit.Text)) then
        Dialog.InitialDir := ExtractFilePath(PayloadPathEdit.Text);
    end;
    if Dialog.Execute then
    begin
      for FileName in Dialog.Files do
        AddPayloadFile(FileName);
      if Dialog.Files.Count > 0 then
        PayloadPathEdit.Text := ExtractFilePath(Dialog.Files[Dialog.Files.Count - 1]);
      RefreshReview;
    end;
  finally
    Dialog.Free;
  end;
end;

procedure TSetupBuildWizardForm.AddPayloadFolderButtonClick(Sender: TObject);
var
  Directory: string;
begin
  Directory := Trim(PayloadPathEdit.Text);
  if TFile.Exists(Directory) then
    Directory := ExtractFilePath(Directory);
  if (Directory = '') or not TDirectory.Exists(Directory) then
    Directory := GetEnvironmentVariable('USERPROFILE');
  if SelectDirectory('Select payload folder', '', Directory) then
    AddPayloadFolder(Directory);
end;

procedure TSetupBuildWizardForm.RemovePayloadButtonClick(Sender: TObject);
begin
  if PayloadList.ItemIndex >= 0 then
  begin
    PayloadList.Items.Delete(PayloadList.ItemIndex);
    RefreshReview;
  end;
end;

procedure TSetupBuildWizardForm.BrowseSourceButtonClick(Sender: TObject);
begin
  BrowseFileInto(ProjectSourceEdit, 'Select project source file',
    'Delphi source and project files (*.fmx;*.pas;*.dpr;*.dproj;*.dfm)|*.fmx;*.pas;*.dpr;*.dproj;*.dfm|All files (*.*)|*.*');
  ApplyProjectSourceFile(ProjectSourceEdit.Text);
end;

procedure TSetupBuildWizardForm.BrowseInstallButtonClick(Sender: TObject);
begin
  BrowseDirectoryInto(InstallFolderEdit, 'Select install folder');
end;

procedure TSetupBuildWizardForm.NewProjectButtonClick(Sender: TObject);
begin
  NewProject;
end;

procedure TSetupBuildWizardForm.BrowseProjectButtonClick(Sender: TObject);
begin
  SaveProject;
end;

procedure TSetupBuildWizardForm.OpenProjectButtonClick(Sender: TObject);
var
  Dialog: TOpenDialog;
  LastProjectFolder: string;
begin
  Dialog := TOpenDialog.Create(nil);
  try
    Dialog.Title := 'Open saved Package Studio Pro project';
    Dialog.Filter := 'Package Studio Pro projects (*.wiproj)|*.wiproj|All files (*.*)|*.*';
    Dialog.Options := Dialog.Options + [TOpenOption.ofFileMustExist];
    LastProjectFolder := '';
    if TFile.Exists(SettingsFileName) then
      LastProjectFolder := Trim(TFile.ReadAllText(SettingsFileName, TEncoding.UTF8));
    if TFile.Exists(LastProjectFolder) then
      LastProjectFolder := ExtractFilePath(LastProjectFolder);
    if TDirectory.Exists(LastProjectFolder) then
      Dialog.InitialDir := LastProjectFolder
    else if Trim(ProjectFileEdit.Text) <> '' then
    begin
      if TFile.Exists(ProjectFileEdit.Text) then
        Dialog.InitialDir := ExtractFilePath(ProjectFileEdit.Text)
      else if TDirectory.Exists(ExtractFilePath(ProjectFileEdit.Text)) then
        Dialog.InitialDir := ExtractFilePath(ProjectFileEdit.Text);
    end;
    if Dialog.Execute then
      LoadProjectFileIntoFields(Dialog.FileName);
  finally
    Dialog.Free;
  end;
end;

procedure TSetupBuildWizardForm.BrowseOutputButtonClick(Sender: TObject);
begin
  BrowseDirectoryInto(OutputFolderEdit, 'Select build output folder');
end;

procedure TSetupBuildWizardForm.BrowseAssociationTargetButtonClick(Sender: TObject);
begin
  BrowseFileInto(AssociationTargetEdit, 'Select association target', 'Executable files (*.exe)|*.exe|All files (*.*)|*.*');
end;

procedure TSetupBuildWizardForm.ProductNameEditChangeTracking(Sender: TObject);
begin
  if FLoadingProject then
    Exit;
  RefreshInstallFolder;
  RefreshAutoPaths;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.CurrentUserRadioChange(Sender: TObject);
begin
  if FUpdatingInstallMode then
    Exit;
  if FLoadingProject then
    Exit;
  if CurrentUserRadio.IsChecked then
  begin
    SelectInstallMode(False, True);
    RefreshReview;
  end;
end;

procedure TSetupBuildWizardForm.ProgramFilesRadioChange(Sender: TObject);
begin
  if FUpdatingInstallMode then
    Exit;
  if FLoadingProject then
    Exit;
  if ProgramFilesRadio.IsChecked then
  begin
    SelectInstallMode(True, True);
    RefreshReview;
  end;
end;

procedure TSetupBuildWizardForm.StartMenuCheckBoxChange(Sender: TObject);
begin
  if FLoadingProject then
    Exit;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.DesktopCheckBoxChange(Sender: TObject);
begin
  if FLoadingProject then
    Exit;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.AddEnvironmentButtonClick(Sender: TObject);
begin
  if (Trim(EnvironmentNameEdit.Text) = '') or (Trim(EnvironmentValueEdit.Text) = '') then
    Exit;
  FProject.EnvironmentVariables.Add(EnvironmentNameEdit.Text + '|' + EnvironmentValueEdit.Text);
  EnvironmentNameEdit.Text := '';
  EnvironmentValueEdit.Text := '';
  RefreshLists;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.RemoveEnvironmentButtonClick(Sender: TObject);
begin
  if EnvironmentList.ItemIndex >= 0 then
  begin
    FProject.EnvironmentVariables.Delete(EnvironmentList.ItemIndex);
    RefreshLists;
    RefreshReview;
  end;
end;

procedure TSetupBuildWizardForm.AddPathEntryButtonClick(Sender: TObject);
begin
  if (FPathEntryEdit = nil) or (Trim(FPathEntryEdit.Text) = '') then
    Exit;
  if FProject.PathEntries.IndexOf(Trim(FPathEntryEdit.Text)) < 0 then
    FProject.PathEntries.Add(Trim(FPathEntryEdit.Text));
  FPathEntryEdit.Text := '';
  RefreshLists;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.RemovePathEntryButtonClick(Sender: TObject);
begin
  if (FPathEntryList <> nil) and (FPathEntryList.ItemIndex >= 0) then
  begin
    FProject.PathEntries.Delete(FPathEntryList.ItemIndex);
    RefreshLists;
    RefreshReview;
  end;
end;

procedure TSetupBuildWizardForm.AddAssociationButtonClick(Sender: TObject);
begin
  if (Trim(AssociationExtensionEdit.Text) = '') or (Trim(AssociationDescriptionEdit.Text) = '') or
    (Trim(AssociationTargetEdit.Text) = '') then
    Exit;
  FProject.FileAssociations.Add(AssociationExtensionEdit.Text + '|' + AssociationDescriptionEdit.Text + '|' +
    AssociationTargetEdit.Text);
  AssociationExtensionEdit.Text := '';
  AssociationDescriptionEdit.Text := '';
  AssociationTargetEdit.Text := '';
  RefreshLists;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.RemoveAssociationButtonClick(Sender: TObject);
begin
  if AssociationList.ItemIndex >= 0 then
  begin
    FProject.FileAssociations.Delete(AssociationList.ItemIndex);
    RefreshLists;
    RefreshReview;
  end;
end;

procedure TSetupBuildWizardForm.AddRegistryButtonClick(Sender: TObject);
begin
  if (Trim(RegistryKeyEdit.Text) = '') or (Trim(RegistryNameEdit.Text) = '') then
    Exit;
  FProject.RegistryEntries.Add(RegistryKeyEdit.Text + '|' + RegistryNameEdit.Text + '|' + RegistryValueEdit.Text);
  RegistryKeyEdit.Text := '';
  RegistryNameEdit.Text := '';
  RegistryValueEdit.Text := '';
  RefreshLists;
  RefreshReview;
end;

procedure TSetupBuildWizardForm.RemoveRegistryButtonClick(Sender: TObject);
begin
  if RegistryList.ItemIndex >= 0 then
  begin
    FProject.RegistryEntries.Delete(RegistryList.ItemIndex);
    RefreshLists;
    RefreshReview;
  end;
end;

procedure TSetupBuildWizardForm.BuildButtonClick(Sender: TObject);
begin
  LogMemo.Lines.Clear;
  RunBuild;
end;

procedure TSetupBuildWizardForm.UserHelpButtonClick(Sender: TObject);
begin
  OpenHelpFile('index.html');
end;

procedure TSetupBuildWizardForm.OpenHelpFile(const AHelpFileName: string);
var
  BasePath: string;
  HelpPath: string;
begin
  BasePath := IncludeTrailingPathDelimiter(ExpandFileName(ExtractFilePath(ParamStr(0)) + '..'));
  HelpPath := BasePath + 'Help\' + AHelpFileName;
  if not FileExists(HelpPath) then
  begin
    Log('Help file not found: ' + HelpPath);
    Exit;
  end;

  ShellExecute(0, 'open', PChar(HelpPath), nil, nil, SW_SHOWNORMAL);
end;

procedure TSetupBuildWizardForm.CloseButtonClick(Sender: TObject);
begin
  Close;
end;

end.

