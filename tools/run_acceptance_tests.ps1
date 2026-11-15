$ErrorActionPreference = 'Stop'

$Root = Split-Path -Parent $PSScriptRoot
Push-Location $Root
$originalUserPath = [Environment]::GetEnvironmentVariable('Path', 'User')
try {
  powershell.exe -ExecutionPolicy Bypass -File '.\tools\build_all.ps1'

  $buildDir = Join-Path $Root 'bin\HelloProductBuild'
  $installDir = Join-Path $Root 'bin\InstalledHelloProduct'
  $runtime = Join-Path $buildDir 'WipRuntime.exe'
  $project = Join-Path $buildDir 'embedded-manifest.json'
  $archive = Join-Path $buildDir 'Hello Product Export.zip'

  if (-not (Test-Path $archive)) { throw 'Export archive was not created.' }
  if (-not (Test-Path (Join-Path $buildDir 'safety-report.txt'))) { throw 'Safety report was not created.' }

  & $runtime $project '--install'
  if ($LASTEXITCODE -ne 0) { throw 'Install failed.' }
  if (-not (Test-Path (Join-Path $installDir 'hello.txt'))) { throw 'Payload file missing after install.' }
  if (-not (Test-Path (Join-Path $installDir 'Shortcuts\Hello Product.lnk'))) { throw 'Shortcut missing after install.' }
  $reg = Get-ItemProperty -Path 'HKCU:\Software\PackageStudioProLab\Hello Product' -Name InstallFolder -ErrorAction SilentlyContinue
  if ($null -eq $reg) { throw 'Product registry value missing after install.' }
  $uninstallKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\PackageStudioPro_Hello Product'
  if (-not (Test-Path $uninstallKey)) { throw 'Uninstall registry key missing after install.' }

  & $runtime $project '--verify'
  if ($LASTEXITCODE -ne 0) { throw 'Verify failed.' }

  Set-Content -LiteralPath (Join-Path $installDir 'hello.txt') -Value 'tampered payload' -Encoding UTF8
  & $runtime $project '--verify'
  if ($LASTEXITCODE -eq 0) { throw 'Verify succeeded after payload tampering.' }

  & $runtime $project '--repair'
  if ($LASTEXITCODE -ne 0) { throw 'Repair failed.' }

  & $runtime $project '--verify'
  if ($LASTEXITCODE -ne 0) { throw 'Verify failed after repair.' }

  & $runtime $project '--uninstall'
  if ($LASTEXITCODE -ne 0) { throw 'Uninstall failed.' }
  if (Test-Path $installDir) { throw 'Install directory still exists after uninstall.' }
  if (Test-Path $uninstallKey) { throw 'Uninstall registry key still exists after uninstall.' }

  $blocked = Join-Path $Root 'bin\AcceptanceBlockedWindows.wiproj'
  @'
{
  "schema": "PackageStudioPro.Project.v1",
  "productName": "Blocked Product",
  "publisher": "Safety Test",
  "version": "1.0.0",
  "installFolder": "C:\\Windows",
  "licenseText": "",
  "signingEnabled": false,
  "signToolPath": "signtool.exe",
  "signingCertificatePath": "",
  "timestampUrl": "http://timestamp.digicert.com",
  "files": [
    "samples\\payload\\hello.txt"
  ],
  "shortcuts": [],
  "registry": []
}
'@ | Set-Content -LiteralPath $blocked -Encoding UTF8
  & '.\bin\WIPBuild.exe' $blocked '.\bin\AcceptanceBlockedBuild'
  if ($LASTEXITCODE -eq 0) { throw 'Protected Windows folder build was not blocked.' }

  $treeRoot = Join-Path $Root 'bin\PayloadTree'
  $treeApp = Join-Path $treeRoot 'app'
  $treePlugins = Join-Path $treeRoot 'plugins'
  New-Item -ItemType Directory -Force -Path $treeApp | Out-Null
  New-Item -ItemType Directory -Force -Path $treePlugins | Out-Null
  Set-Content -LiteralPath (Join-Path $treeApp 'same.txt') -Value 'app file' -Encoding UTF8
  Set-Content -LiteralPath (Join-Path $treePlugins 'same.txt') -Value 'plugin file' -Encoding UTF8
  $treeProject = Join-Path $Root 'bin\TreePayload.wiproj'
  $treeInstall = Join-Path $Root 'bin\InstalledTreePayload'
  @"
{
  "schema": "PackageStudioPro.Project.v1",
  "productName": "Tree Payload",
  "publisher": "Safety Test",
  "version": "1.0.0",
  "installFolder": "$($treeInstall.Replace('\','\\'))",
  "licenseText": "",
  "signingEnabled": false,
  "signToolPath": "signtool.exe",
  "signingCertificatePath": "",
  "timestampUrl": "http://timestamp.digicert.com",
  "files": [
    "$((Join-Path $treeApp 'same.txt').Replace('\','\\'))",
    "$((Join-Path $treePlugins 'same.txt').Replace('\','\\'))"
  ],
  "shortcuts": [],
  "registry": [],
  "environment": [],
  "fileAssociations": [],
  "prerequisites": [],
  "features": []
}
"@ | Set-Content -LiteralPath $treeProject -Encoding UTF8

  & '.\bin\WIPBuild.exe' $treeProject '.\bin\TreePayloadBuild'
  if ($LASTEXITCODE -ne 0) { throw 'Tree payload build failed.' }
  $treeRuntime = Join-Path $Root 'bin\TreePayloadBuild\WipRuntime.exe'
  $treePackage = Join-Path $Root 'bin\TreePayloadBuild\embedded-manifest.json'
  & $treeRuntime $treePackage '--install'
  if ($LASTEXITCODE -ne 0) { throw 'Tree payload install failed.' }
  if (-not (Test-Path (Join-Path $treeInstall 'app\same.txt'))) { throw 'Tree payload app file missing.' }
  if (-not (Test-Path (Join-Path $treeInstall 'plugins\same.txt'))) { throw 'Tree payload plugin file missing.' }
  & $treeRuntime $treePackage '--uninstall'
  if ($LASTEXITCODE -ne 0) { throw 'Tree payload uninstall failed.' }

  $pathInstall = Join-Path $Root "bin\InstalledPathPayload_$PID"
  $pathProject = Join-Path $Root 'bin\PathPayload.wiproj'
  @"
{
  "schema": "PackageStudioPro.Project.v1",
  "productName": "Path Payload",
  "publisher": "Safety Test",
  "version": "1.0.0",
  "installFolder": "$($pathInstall.Replace('\','\\'))",
  "licenseText": "",
  "signingEnabled": false,
  "signToolPath": "signtool.exe",
  "signingCertificatePath": "",
  "timestampUrl": "http://timestamp.digicert.com",
  "files": [
    "samples\\payload\\hello.txt"
  ],
  "shortcuts": [],
  "registry": [],
  "environment": [],
  "pathEntries": [
    "{app}"
  ],
  "fileAssociations": [],
  "prerequisites": [],
  "features": []
}
"@ | Set-Content -LiteralPath $pathProject -Encoding UTF8

  & '.\bin\WIPBuild.exe' $pathProject '.\bin\PathPayloadBuild'
  if ($LASTEXITCODE -ne 0) { throw 'PATH payload build failed.' }
  $pathRuntime = Join-Path $Root 'bin\PathPayloadBuild\WipRuntime.exe'
  $pathPackage = Join-Path $Root 'bin\PathPayloadBuild\embedded-manifest.json'
  & $pathRuntime $pathPackage '--install'
  if ($LASTEXITCODE -ne 0) { throw 'PATH payload install failed.' }
  $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $pathParts = $currentPath -split ';' | ForEach-Object { $_.Trim().TrimEnd('\') }
  if ($pathParts -notcontains $pathInstall.TrimEnd('\')) { throw 'PATH entry missing after install.' }
  & $pathRuntime $pathPackage '--uninstall'
  if ($LASTEXITCODE -ne 0) { throw 'PATH payload uninstall failed.' }
  $currentPath = [Environment]::GetEnvironmentVariable('Path', 'User')
  $pathParts = $currentPath -split ';' | ForEach-Object { $_.Trim().TrimEnd('\') }
  if ($pathParts -contains $pathInstall.TrimEnd('\')) { throw 'PATH entry remained after uninstall.' }

  'ACCEPTANCE_TESTS_PASSED'
}
finally {
  [Environment]::SetEnvironmentVariable('Path', $originalUserPath, 'User')
  Pop-Location
}

