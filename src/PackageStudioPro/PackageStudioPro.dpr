program PackageStudioPro;

{$R *.res}

uses
  System.StartUpCopy,
  FMX.Forms,
  WizardForm in 'WizardForm.pas',
  Wip.Project in '..\Shared\Wip.Project.pas',
  Wip.Safety in '..\Shared\Wip.Safety.pas';

begin
  Application.Initialize;
  Application.CreateForm(TSetupBuildWizardForm, SetupBuildWizardForm);
  Application.Run;
end.


