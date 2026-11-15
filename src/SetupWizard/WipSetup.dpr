program WipSetup;

{$R *.res}

uses
  System.StartUpCopy,
  FMX.Forms,
  SetupForm in 'SetupForm.pas',
  Wip.Project in '..\Shared\Wip.Project.pas',
  Wip.InstallEngine in '..\Shared\Wip.InstallEngine.pas';

begin
  Application.Initialize;
  Application.CreateForm(TSetupWizardForm, SetupWizardForm);
  Application.Run;
end.

