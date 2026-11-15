param([switch]$SkipSample)
$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
$RsVars = 'C:\Program Files (x86)\Embarcadero\Studio\37.0\bin\rsvars.bat'

Push-Location $Root
try {
  if (-not (Test-Path '.\bin')) {
    New-Item -ItemType Directory -Path '.\bin' | Out-Null
  }
  if (-not (Test-Path '.\bin\dcus')) {
    New-Item -ItemType Directory -Path '.\bin\dcus' | Out-Null
  }
  $Rc = 'C:\Program Files (x86)\Windows Kits\10\bin\10.0.26100.0\x86\rc.exe'
  if (-not (Test-Path $Rc)) {
    $Rc = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Recurse -Filter rc.exe -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\x86\\rc\.exe$' } |
      Select-Object -First 1 -ExpandProperty FullName
  }
  if (-not $Rc) { throw 'Windows resource compiler rc.exe was not found.' }

  & $Rc /fo '.\src\SetupRuntime\WipRuntime.res' '.\src\SetupRuntime\WipRuntime.rc'
  if ($LASTEXITCODE -ne 0) { throw 'WipRuntime resource compile failed.' }
  & $Rc /fo '.\src\SetupWizard\WipSetup.res' '.\src\SetupWizard\WipSetup.rc'
  if ($LASTEXITCODE -ne 0) { throw 'WipSetup resource compile failed.' }
  & $Rc /fo '.\src\WIPBuild\WIPBuild.res' '.\src\WIPBuild\WIPBuild.rc'
  if ($LASTEXITCODE -ne 0) { throw 'WIPBuild resource compile failed.' }
  & $Rc /fo '.\src\PackageStudioPro\PackageStudioPro.res' '.\src\PackageStudioPro\PackageStudioPro.rc'
  if ($LASTEXITCODE -ne 0) { throw 'PackageStudioPro resource compile failed.' }

  cmd.exe /c "call `"$RsVars`" & dcc32 -Q -B -NSSystem;System.SysUtils;System.Classes;System.JSON;System.IOUtils;System.Win.ComObj;System.Win.Registry;Winapi.ActiveX;Winapi.ShlObj;Winapi.Windows -Usrc\Shared -NUbin\dcus -Ebin src\SetupRuntime\WipRuntime.dpr"
  if ($LASTEXITCODE -ne 0) { throw 'WipRuntime compile failed.' }

  cmd.exe /c "call `"$RsVars`" & dcc32 -Q -B -NSSystem;System.SysUtils;System.Classes;System.JSON;System.Types;System.UITypes;System.IOUtils;System.Win.ComObj;System.Win.Registry;Winapi.ActiveX;Winapi.ShlObj;Winapi.Windows;FMX.Forms;FMX.Controls;FMX.StdCtrls;FMX.Layouts;FMX.Memo;FMX.Objects;FMX.Types;FMX.Edit;FMX.Dialogs -Usrc\Shared;src\SetupWizard -NUbin\dcus -Ebin src\SetupWizard\WipSetup.dpr"
  if ($LASTEXITCODE -ne 0) { throw 'WipSetup compile failed.' }

  cmd.exe /c "call `"$RsVars`" & dcc32 -Q -B -NSSystem;System.SysUtils;System.Classes;System.JSON;System.IOUtils;System.Zip;Winapi.Windows -Usrc\Shared -NUbin\dcus -Ebin src\WIPBuild\WIPBuild.dpr"
  if ($LASTEXITCODE -ne 0) { throw 'WIPBuild compile failed.' }

  cmd.exe /c "call `"$RsVars`" & dcc32 -Q -B -NSSystem;System.SysUtils;System.Classes;System.JSON;System.Types;System.UITypes;Winapi.Windows;FMX.Forms;FMX.Controls;FMX.StdCtrls;FMX.Layouts;FMX.Memo;FMX.TreeView;FMX.Edit;FMX.Types;FMX.ListBox;FMX.Objects;FMX.Graphics;FMX.Dialogs -Usrc\Shared;src\PackageStudioPro -NUbin\dcus -Ebin src\PackageStudioPro\PackageStudioPro.dpr"
  if ($LASTEXITCODE -ne 0) { throw 'PackageStudioPro compile failed.' }

  $mt = 'C:\Program Files (x86)\Windows Kits\10\bin\x64\mt.exe'
  if (-not (Test-Path $mt)) {
    $mt = Get-ChildItem 'C:\Program Files (x86)\Windows Kits\10\bin' -Recurse -Filter mt.exe -ErrorAction SilentlyContinue |
      Where-Object { $_.FullName -match '\\x64\\mt\.exe$' } |
      Select-Object -First 1 -ExpandProperty FullName
  }
  if (-not $mt) { throw 'Windows manifest tool mt.exe was not found.' }
  & $mt -manifest '.\src\SetupRuntime\WipRuntime.manifest' -outputresource:'.\bin\WipRuntime.exe;#1'
  if ($LASTEXITCODE -ne 0) { throw 'WipRuntime manifest embed failed.' }
  & $mt -manifest '.\src\SetupWizard\WipSetup.manifest' -outputresource:'.\bin\WipSetup.exe;#1'
  if ($LASTEXITCODE -ne 0) { throw 'WipSetup manifest embed failed.' }
  & $mt -manifest '.\src\WIPBuild\WIPBuild.manifest' -outputresource:'.\bin\WIPBuild.exe;#1'
  if ($LASTEXITCODE -ne 0) { throw 'WIPBuild manifest embed failed.' }
  & $mt -manifest '.\src\PackageStudioPro\PackageStudioPro.manifest' -outputresource:'.\bin\PackageStudioPro.exe;#1'
  if ($LASTEXITCODE -ne 0) { throw 'PackageStudioPro manifest embed failed.' }

  if (-not $SkipSample) {
    & '.\bin\WIPBuild.exe' '.\samples\HelloProduct.wiproj' '.\bin\HelloProductBuild'
    if ($LASTEXITCODE -ne 0) { throw 'Sample build failed.' }
  }
}
finally {
  Pop-Location
}

