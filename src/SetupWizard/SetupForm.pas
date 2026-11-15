unit SetupForm;

interface

uses
  System.Classes, System.IOUtils, System.SysUtils, System.Types, System.UITypes, System.Zip,
  FMX.Controls, FMX.Dialogs, FMX.Edit, FMX.Forms, FMX.StdCtrls, FMX.Layouts, FMX.Memo, FMX.Objects,
  FMX.Types, Winapi.ShellAPI, Winapi.Windows, Wip.InstallEngine, Wip.Project,
  FMX.Memo.Types, FMX.ScrollBox, FMX.Controls.Presentation;

type
  TSetupWizardForm = class(TForm)
    StartupTimer: TTimer;
    TopPanel: TRectangle;
    BrandIcon: TRectangle;
    BrandWindow: TRectangle;
    BrandPane1: TRectangle;
    BrandPane2: TRectangle;
    BrandPane3: TRectangle;
    BrandPane4: TRectangle;
    BrandDial: TRectangle;
    BrandArrowLabel: TLabel;
    BrandNameLabel: TLabel;
    BrandSloganLabel: TLabel;
    ContentPanel: TRectangle;
    ProductNameLabel: TLabel;
    InstallFolderLabel: TLabel;
    InstallFolderEdit: TEdit;
    BrowseInstallFolderButton: TButton;
    PackageInfoLabel: TLabel;
    ItemsLabel: TLabel;
    RequiredAppCheckBox: TCheckBox;
    RequiredHelpCheckBox: TCheckBox;
    StartMenuCheckBox: TCheckBox;
    DesktopCheckBox: TCheckBox;
    LicenseLabel: TLabel;
    SummaryMemo: TMemo;
    LicenseMemo: TMemo;
    AcceptEulaCheckBox: TCheckBox;
    LogPanel: TRectangle;
    StatusLabel: TLabel;
    LogMemo: TMemo;
    ButtonPanel: TLayout;
    FooterBrandIcon: TRectangle;
    FooterBrandWindow: TRectangle;
    FooterBrandPane1: TRectangle;
    FooterBrandPane2: TRectangle;
    FooterBrandPane3: TRectangle;
    FooterBrandPane4: TRectangle;
    FooterBrandDial: TRectangle;
    FooterBrandArrowLabel: TLabel;
    FooterBrandLabel: TLabel;
    InstallButton: TButton;
    RepairButton: TButton;
    VerifyButton: TButton;
    UninstallButton: TButton;
    UserHelpButton: TButton;
    CloseButton: TButton;
    WelcomePanel: TRectangle;
    WelcomeAccentPanel: TRectangle;
    WelcomeAccentTitleLabel: TLabel;
    WelcomeAccentSloganLabel: TLabel;
    WelcomeTitleLabel: TLabel;
    WelcomeSubtitleLabel: TLabel;
    WelcomeInstructionLabel: TLabel;
    WelcomeInfoLabel: TLabel;
    ContinueButton: TButton;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure InstallButtonClick(Sender: TObject);
    procedure RepairButtonClick(Sender: TObject);
    procedure VerifyButtonClick(Sender: TObject);
    procedure UninstallButtonClick(Sender: TObject);
    procedure UserHelpButtonClick(Sender: TObject);
    procedure CloseButtonClick(Sender: TObject);
    procedure BrowseInstallFolderButtonClick(Sender: TObject);
    procedure StartupTimerTimer(Sender: TObject);
    procedure AcceptEulaCheckBoxChange(Sender: TObject);
    procedure ContinueButtonClick(Sender: TObject);
  private
    FProject: TWipProject;
    FOriginalShortcuts: TStringList;
    FProjectFile: string;
    FExtractedPackageFolder: string;
    FLastLogFile: string;
    function ExtractEmbeddedPackage(out AProjectFile: string): Boolean;
    procedure ApplyInstallerOptions;
    function HasShortcutLocation(const ALocation: string): Boolean;
    procedure AddLogLine(const AMessage: string);
    procedure EngineLog(const AMessage: string);
    procedure LoadProject;
    procedure RefreshSummary;
    procedure ShowInstallScreen;
    procedure ShowWelcomeScreen;
    procedure UpdateActionButtons;
    function ModeCaption(AMode: TWipInstallMode): string;
    procedure RunEngine(AMode: TWipInstallMode);
  end;

var
  SetupWizardForm: TSetupWizardForm;

implementation

{$R *.fmx}

const
  EmbeddedPackageMarker = 'PSPSETUPBUNDLE1';

procedure TSetupWizardForm.FormCreate(Sender: TObject);
begin
  WindowState := TWindowState.wsMaximized;
  FProject := TWipProject.Create;
  FOriginalShortcuts := TStringList.Create;
  FExtractedPackageFolder := '';
  FProjectFile := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'install.wiproj';
  BrandSloganLabel.Text := 'From App to Installer in Minutes.';
  WelcomePanel.Visible := False;
  ContentPanel.Visible := False;
  LogPanel.Visible := False;
  StatusLabel.Text := 'Preparing setup package...';
  LogMemo.Lines.Clear;
  InstallButton.Enabled := False;
  RepairButton.Enabled := False;
  VerifyButton.Enabled := False;
  UninstallButton.Enabled := False;
  AcceptEulaCheckBox.IsChecked := False;
  AcceptEulaCheckBox.Enabled := False;
  StartupTimer.Interval := 100;
  StartupTimer.Enabled := True;
end;

procedure TSetupWizardForm.FormDestroy(Sender: TObject);
begin
  if (FExtractedPackageFolder <> '') and TDirectory.Exists(FExtractedPackageFolder) then
    TDirectory.Delete(FExtractedPackageFolder, True);
  FProject.Free;
  FOriginalShortcuts.Free;
end;

function TSetupWizardForm.ExtractEmbeddedPackage(out AProjectFile: string): Boolean;
var
  ExeStream: TFileStream;
  BundleStream: TMemoryStream;
  Zip: TZipFile;
  MarkerBytes: TBytes;
  TailBytes: TBytes;
  SizeBytes: TBytes;
  BundleSize: Int64;
  MarkerStart, PackageEnd, CertificateOffset: Int64;
  PeOffset: Integer; Signature: Cardinal; Magic: Word; AlignmentByte: Byte;
  CertificateSize, CertificateStart: Cardinal; Padding, EntryIndex: Integer;
  EntryName, EntryPath: string; ExpandedBytes: UInt64; Header: TZipHeader;
  ExtractionId: TGUID;
  EntryNames: TStringList;
begin
  Result := False;
  AProjectFile := '';
  MarkerBytes := TEncoding.ASCII.GetBytes(EmbeddedPackageMarker);
  ExeStream := TFileStream.Create(ParamStr(0), fmOpenRead or fmShareDenyNone);
  try
    if ExeStream.Size < Length(MarkerBytes) + SizeOf(BundleSize) then
      Exit;

    PackageEnd := ExeStream.Size;
    ExeStream.Position := $3C; ExeStream.ReadBuffer(PeOffset, SizeOf(PeOffset));
    if (PeOffset < $40) or (Int64(PeOffset) + 24 + 152 > ExeStream.Size) then Exit;
    ExeStream.Position := PeOffset; ExeStream.ReadBuffer(Signature, SizeOf(Signature));
    if Signature <> $00004550 then Exit;
    ExeStream.Position := PeOffset + 24; ExeStream.ReadBuffer(Magic, SizeOf(Magic));
    if Magic = $10B then CertificateOffset := PeOffset + 24 + 128
    else if Magic = $20B then CertificateOffset := PeOffset + 24 + 144
    else Exit;
    ExeStream.Position := CertificateOffset;
    ExeStream.ReadBuffer(CertificateStart, SizeOf(CertificateStart));
    ExeStream.ReadBuffer(CertificateSize, SizeOf(CertificateSize));
    if CertificateStart <> 0 then begin
      if (CertificateStart < Cardinal(PeOffset + 24 + 152)) or (CertificateSize < 8) or
         (UInt64(CertificateStart) + CertificateSize <> UInt64(ExeStream.Size)) then Exit;
      PackageEnd := CertificateStart;
    end;
    SetLength(TailBytes, Length(MarkerBytes));
    for Padding := 0 to 7 do begin
      ExeStream.Position := PackageEnd - Padding - Length(MarkerBytes);
      ExeStream.ReadBuffer(TailBytes[0], Length(TailBytes));
      if CompareMem(@TailBytes[0], @MarkerBytes[0], Length(MarkerBytes)) then begin
        Dec(PackageEnd, Padding); Break;
      end;
      if (CertificateStart = 0) or (Padding = 7) then Exit;
      ExeStream.Position := PackageEnd - Padding - 1;
      ExeStream.ReadBuffer(AlignmentByte, 1);
      if AlignmentByte <> 0 then Exit;
    end;

    SetLength(SizeBytes, SizeOf(BundleSize));
    ExeStream.Position := PackageEnd - Length(MarkerBytes) - SizeOf(BundleSize);
    ExeStream.ReadBuffer(SizeBytes[0], Length(SizeBytes));
    Move(SizeBytes[0], BundleSize, SizeOf(BundleSize));
    if (BundleSize <= 0) or (BundleSize > 512 * 1024 * 1024) or (BundleSize > ExeStream.Size) then
      Exit;

    MarkerStart := PackageEnd - Length(MarkerBytes) - SizeOf(BundleSize);
    if BundleSize > MarkerStart then
      Exit;

    BundleStream := TMemoryStream.Create;
    try
      ExeStream.Position := MarkerStart - BundleSize;
      BundleStream.CopyFrom(ExeStream, BundleSize);
      BundleStream.Position := 0;

      CreateGUID(ExtractionId);
      FExtractedPackageFolder := System.IOUtils.TPath.Combine(System.IOUtils.TPath.GetTempPath,
        'PackageStudioPro_' + GUIDToString(ExtractionId));
      if not CreateDirectory(PChar(FExtractedPackageFolder), nil) then RaiseLastOSError;

      Zip := TZipFile.Create;
      EntryNames := TStringList.Create;
      EntryNames.CaseSensitive := False; EntryNames.Sorted := True;
      try
        Zip.Open(BundleStream, zmRead);
        if Zip.FileCount > 50000 then raise EInvalidOperation.Create('Too many package entries.');
        ExpandedBytes := 0;
        for EntryIndex := 0 to Zip.FileCount - 1 do begin
          EntryName := StringReplace(Zip.FileNames[EntryIndex], '/', '\', [rfReplaceAll]);
          EntryPath := System.IOUtils.TPath.GetFullPath(System.IOUtils.TPath.Combine(FExtractedPackageFolder, EntryName));
          if (Pos(':', EntryName) > 0) or System.IOUtils.TPath.IsPathRooted(EntryName) or
             not EntryPath.StartsWith(IncludeTrailingPathDelimiter(FExtractedPackageFolder), True) then
            raise EInvalidOperation.Create('Unsafe package entry: ' + EntryName);
          if EntryNames.IndexOf(EntryPath) >= 0 then raise EInvalidOperation.Create('Duplicate package entry: ' + EntryName);
          EntryNames.Add(EntryPath);
          Header := Zip.FileInfo[EntryIndex];
          Inc(ExpandedBytes, Header.UncompressedSize);
          if (Header.UncompressedSize = $FFFFFFFF) or (ExpandedBytes > UInt64(4) * 1024 * 1024 * 1024) then
            raise EInvalidOperation.Create('Package expansion exceeds the 4 GiB limit.');
        end;
        Zip.ExtractAll(FExtractedPackageFolder);
      finally
        EntryNames.Free;
        Zip.Free;
      end;

      AProjectFile := IncludeTrailingPathDelimiter(FExtractedPackageFolder) + 'install.wiproj';
      Result := FileExists(AProjectFile);
    finally
      BundleStream.Free;
    end;
  finally
    ExeStream.Free;
  end;
end;

procedure TSetupWizardForm.LoadProject;
begin
  if FileExists(FProjectFile) then
  begin
    FProject.LoadFromFile(FProjectFile);
    FOriginalShortcuts.Assign(FProject.Shortcuts);
    RefreshSummary;
    ShowWelcomeScreen;
    AcceptEulaCheckBox.IsChecked := False;
    AcceptEulaCheckBox.Enabled := True;
    UpdateActionButtons;
  end
  else
  begin
    ProductNameLabel.Text := 'Setup package problem';
    InstallFolderLabel.Text := '';
    PackageInfoLabel.Text := '';
    SummaryMemo.Lines.Text := 'This setup file does not contain an embedded install package.';
    LicenseMemo.Lines.Clear;
    StatusLabel.Text := 'Setup cannot continue.';
    InstallButton.Enabled := False;
    RepairButton.Enabled := False;
    VerifyButton.Enabled := False;
    UninstallButton.Enabled := False;
    AcceptEulaCheckBox.IsChecked := False;
    AcceptEulaCheckBox.Enabled := False;
    WelcomePanel.Visible := False;
    ContentPanel.Visible := True;
    LogPanel.Visible := True;
  end;
end;

function TSetupWizardForm.HasShortcutLocation(const ALocation: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to FOriginalShortcuts.Count - 1 do
    if FOriginalShortcuts[I].StartsWith(ALocation + '|', True) then
      Exit(True);
end;

procedure TSetupWizardForm.ApplyInstallerOptions;
var
  I: Integer;
  ShortcutEntry: string;
begin
  FProject.InstallFolder := Trim(InstallFolderEdit.Text);
  FProject.Shortcuts.Clear;
  for I := 0 to FOriginalShortcuts.Count - 1 do
  begin
    ShortcutEntry := FOriginalShortcuts[I];
    if ShortcutEntry.StartsWith('StartMenu|', True) then
    begin
      if StartMenuCheckBox.IsChecked then
        FProject.Shortcuts.Add(ShortcutEntry);
    end
    else if ShortcutEntry.StartsWith('Desktop|', True) then
    begin
      if DesktopCheckBox.IsChecked then
        FProject.Shortcuts.Add(ShortcutEntry);
    end
    else
      FProject.Shortcuts.Add(ShortcutEntry);
  end;
end;

procedure TSetupWizardForm.RefreshSummary;
begin
  ProductNameLabel.Text := FProject.ProductName;
  WelcomeAccentTitleLabel.Text := FProject.ProductName;
  WelcomeTitleLabel.Text := 'Welcome to ' + FProject.ProductName + ' Setup';
  WelcomeSubtitleLabel.Text := 'This wizard will install ' + FProject.ProductName + ' on your computer.';
  WelcomeInfoLabel.Text := 'Publisher: ' + FProject.Publisher + '   |   Version ' + FProject.Version +
    '   |   Files: ' + FProject.Files.Count.ToString;
  InstallFolderEdit.Text := FProject.InstallFolder;
  InstallFolderLabel.Text := 'Install folder';
  PackageInfoLabel.Text := '';
  RequiredAppCheckBox.IsChecked := True;
  RequiredAppCheckBox.Enabled := False;
  RequiredHelpCheckBox.IsChecked := True;
  RequiredHelpCheckBox.Enabled := False;
  StartMenuCheckBox.IsChecked := HasShortcutLocation('StartMenu');
  StartMenuCheckBox.Enabled := HasShortcutLocation('StartMenu');
  DesktopCheckBox.IsChecked := HasShortcutLocation('Desktop');
  DesktopCheckBox.Enabled := HasShortcutLocation('Desktop');
  SummaryMemo.Lines.BeginUpdate;
  try
    SummaryMemo.Lines.Clear;
    SummaryMemo.Lines.Add('This wizard will install ' + FProject.ProductName + ' on this computer.');
    SummaryMemo.Lines.Add('');
    SummaryMemo.Lines.Add('Click Install to continue. If this product is already installed, use Repair, Verify, or Uninstall.');
    if Trim(FProject.LicenseText) = '' then
      LicenseMemo.Lines.Text := 'No license text was included with this package.'
    else
      LicenseMemo.Lines.Text := FProject.LicenseText;
  finally
    SummaryMemo.Lines.EndUpdate;
  end;
end;

procedure TSetupWizardForm.ShowWelcomeScreen;
begin
  WelcomePanel.Visible := True;
  ContentPanel.Visible := False;
  LogPanel.Visible := False;
  InstallButton.Visible := False;
  RepairButton.Visible := False;
  VerifyButton.Visible := False;
  UninstallButton.Visible := False;
  UserHelpButton.Visible := False;
  StatusLabel.Text := 'Ready to install.';
end;

procedure TSetupWizardForm.ShowInstallScreen;
begin
  WelcomePanel.Visible := False;
  ContentPanel.Visible := True;
  LogPanel.Visible := True;
  InstallButton.Visible := True;
  RepairButton.Visible := True;
  VerifyButton.Visible := True;
  UninstallButton.Visible := True;
  UserHelpButton.Visible := True;
  StatusLabel.Text := 'Ready to install.';
  UpdateActionButtons;
end;

procedure TSetupWizardForm.UpdateActionButtons;
var
  Ready: Boolean;
begin
  Ready := FileExists(FProjectFile) and AcceptEulaCheckBox.IsChecked;
  InstallButton.Enabled := Ready;
  RepairButton.Enabled := Ready;
  VerifyButton.Enabled := Ready;
  UninstallButton.Enabled := Ready;
end;

procedure TSetupWizardForm.AcceptEulaCheckBoxChange(Sender: TObject);
begin
  UpdateActionButtons;
end;

procedure TSetupWizardForm.ContinueButtonClick(Sender: TObject);
begin
  ShowInstallScreen;
end;

function TSetupWizardForm.ModeCaption(AMode: TWipInstallMode): string;
begin
  case AMode of
    imInstall:
      Result := 'Install';
    imRepair:
      Result := 'Repair';
    imVerify:
      Result := 'Verify';
    imUninstall:
      Result := 'Uninstall';
  else
    Result := 'Run';
  end;
end;

procedure TSetupWizardForm.AddLogLine(const AMessage: string);
begin
  if Trim(AMessage) = '' then
    Exit;
  LogMemo.Lines.Add(AMessage);
  Application.ProcessMessages;
end;

procedure TSetupWizardForm.EngineLog(const AMessage: string);
begin
  AddLogLine(AMessage);
end;

procedure TSetupWizardForm.RunEngine(AMode: TWipInstallMode);
var
  Engine: TWipInstallEngine;
  Log: TStringList;
  I: Integer;
  HadError: Boolean;
  Caption: string;
  RunningText: string;
  CompletedText: string;
  FailedText: string;
begin
  if not AcceptEulaCheckBox.IsChecked then
  begin
    StatusLabel.Text := 'Accept the license agreement before continuing.';
    Exit;
  end;
  if AMode in [imInstall, imRepair] then
    ApplyInstallerOptions;
  Caption := ModeCaption(AMode);
  case AMode of
    imInstall:
      begin
        RunningText := 'Installing...';
        CompletedText := 'Install completed.';
        FailedText := 'Install failed.';
      end;
    imRepair:
      begin
        RunningText := 'Repairing...';
        CompletedText := 'Repair completed.';
        FailedText := 'Repair failed.';
      end;
    imVerify:
      begin
        RunningText := 'Verifying...';
        CompletedText := 'Verify completed.';
        FailedText := 'Verify failed.';
      end;
    imUninstall:
      begin
        RunningText := 'Uninstalling...';
        CompletedText := 'Uninstall completed.';
        FailedText := 'Uninstall failed.';
      end;
  else
    begin
      RunningText := Caption + ' is running...';
      CompletedText := Caption + ' completed.';
      FailedText := Caption + ' failed.';
    end;
  end;
  StatusLabel.Text := RunningText;
  LogMemo.Lines.Clear;
  AddLogLine(Caption + ' started.');
  Log := TStringList.Create;
  try
    Engine := TWipInstallEngine.Create(Log, ExtractFilePath(FProjectFile));
    try
      Engine.OnLog := EngineLog;
      try
        Engine.Execute(FProject, AMode);
      except
        on E: Exception do
        begin
          Log.Add('ERROR: ' + E.ClassName + ': ' + E.Message);
          AddLogLine('ERROR: ' + E.ClassName + ': ' + E.Message);
        end;
      end;
    finally
      Engine.Free;
    end;

    FLastLogFile := IncludeTrailingPathDelimiter(GetEnvironmentVariable('TEMP')) +
      'PackageStudioPro_' + Caption + '_' + GetTickCount.ToString + '.log';

    HadError := False;
    for I := 0 to Log.Count - 1 do
      if Log[I].StartsWith('ERROR:', True) or Log[I].StartsWith('Verify hash mismatch', True) or
        Log[I].StartsWith('Verify missing', True) then
        HadError := True;
    if HadError then
    begin
      StatusLabel.Text := FailedText;
      Log.Add(FailedText);
      AddLogLine(FailedText);
    end
    else
    begin
      StatusLabel.Text := CompletedText;
      Log.Add(CompletedText);
      AddLogLine(CompletedText);
    end;
    Log.Add('Full log saved to: ' + FLastLogFile);
    AddLogLine('Full log saved to: ' + FLastLogFile);
    Log.SaveToFile(FLastLogFile, TEncoding.UTF8);
  finally
    Log.Free;
  end;
end;

procedure TSetupWizardForm.InstallButtonClick(Sender: TObject);
begin
  RunEngine(imInstall);
end;

procedure TSetupWizardForm.RepairButtonClick(Sender: TObject);
begin
  RunEngine(imRepair);
end;

procedure TSetupWizardForm.VerifyButtonClick(Sender: TObject);
begin
  RunEngine(imVerify);
end;

procedure TSetupWizardForm.UninstallButtonClick(Sender: TObject);
begin
  RunEngine(imUninstall);
end;

procedure TSetupWizardForm.UserHelpButtonClick(Sender: TObject);
var
  HelpPath: string;
begin
  HelpPath := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + 'Help\index.html';
  if not FileExists(HelpPath) then
  begin
    StatusLabel.Text := 'Help file not found: ' + HelpPath;
    LogMemo.Lines.Add('ERROR: Help file not found: ' + HelpPath);
    Exit;
  end;
  ShellExecute(0, 'open', PChar(HelpPath), nil, nil, SW_SHOWNORMAL);
end;

procedure TSetupWizardForm.CloseButtonClick(Sender: TObject);
begin
  Close;
end;

procedure TSetupWizardForm.BrowseInstallFolderButtonClick(Sender: TObject);
var
  FolderName: string;
begin
  FolderName := InstallFolderEdit.Text;
  if SelectDirectory('Select install folder', '', FolderName) then
    InstallFolderEdit.Text := FolderName;
end;

procedure TSetupWizardForm.StartupTimerTimer(Sender: TObject);
begin
  StartupTimer.Enabled := False;
  if not FileExists(FProjectFile) then
    ExtractEmbeddedPackage(FProjectFile);
  LoadProject;
end;

end.

