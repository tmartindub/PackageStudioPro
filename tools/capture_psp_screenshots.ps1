$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class PspCaptureWin32 {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
  [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);
  [DllImport("user32.dll")] public static extern bool ClientToScreen(IntPtr hWnd, ref POINT point);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr hwnd, IntPtr hdcBlt, int nFlags);
  [DllImport("user32.dll")] public static extern bool SetCursorPos(int X, int Y);
  [DllImport("user32.dll")] public static extern void mouse_event(uint flags, uint dx, uint dy, uint data, UIntPtr extraInfo);
  public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
  public const uint MOUSEEVENTF_LEFTUP = 0x0004;
  public struct RECT { public int Left; public int Top; public int Right; public int Bottom; }
  public struct POINT { public int X; public int Y; }
}
"@

function Get-ProcessWindow {
  param([int] $ProcessId)

  $script:PspCaptureProcessId = $ProcessId
  $script:PspCaptureWindows = New-Object System.Collections.Generic.List[System.IntPtr]
  $callback = [PspCaptureWin32+EnumWindowsProc] {
    param([IntPtr] $hWnd, [IntPtr] $lParam)

    $windowProcessId = 0
    [PspCaptureWin32]::GetWindowThreadProcessId($hWnd, [ref] $windowProcessId) | Out-Null
    if (($windowProcessId -eq $script:PspCaptureProcessId) -and [PspCaptureWin32]::IsWindowVisible($hWnd)) {
      $rect = New-Object PspCaptureWin32+RECT
      [PspCaptureWin32]::GetWindowRect($hWnd, [ref] $rect) | Out-Null
      if (($rect.Right - $rect.Left) -gt 200 -and ($rect.Bottom - $rect.Top) -gt 200) {
        $script:PspCaptureWindows.Add($hWnd)
      }
    }
    return $true
  }

  [PspCaptureWin32]::EnumWindows($callback, [IntPtr]::Zero) | Out-Null
  if ($script:PspCaptureWindows.Count -gt 0) {
    return $script:PspCaptureWindows[0]
  }

  return [IntPtr]::Zero
}

function Click-Client {
  param(
    [IntPtr] $Handle,
    [int] $X,
    [int] $Y
  )
  $point = New-Object PspCaptureWin32+POINT
  $point.X = $X
  $point.Y = $Y
  [PspCaptureWin32]::ClientToScreen($Handle, [ref] $point) | Out-Null
  [PspCaptureWin32]::SetCursorPos($point.X, $point.Y) | Out-Null
  Start-Sleep -Milliseconds 120
  [PspCaptureWin32]::mouse_event([PspCaptureWin32]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
  [PspCaptureWin32]::mouse_event([PspCaptureWin32]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
}

function Capture-Window {
  param(
    [IntPtr] $Handle,
    [string] $Path
  )
  $rect = New-Object PspCaptureWin32+RECT
  [PspCaptureWin32]::GetWindowRect($Handle, [ref] $rect) | Out-Null
  $width = $rect.Right - $rect.Left
  $height = $rect.Bottom - $rect.Top
  $workingArea = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea
  if (($rect.Top + $height) -gt $workingArea.Bottom) {
    $height = $workingArea.Bottom - $rect.Top
  }
  $bitmap = New-Object System.Drawing.Bitmap($width, $height)
  try {
    $screenBounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    $screenBitmap = New-Object System.Drawing.Bitmap($screenBounds.Width, $screenBounds.Height)
    $screenGraphics = [System.Drawing.Graphics]::FromImage($screenBitmap)
    $screenGraphics.CopyFromScreen($screenBounds.Left, $screenBounds.Top, 0, 0, [System.Drawing.Size]::new($screenBounds.Width, $screenBounds.Height))
    $screenGraphics.Dispose()

    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $sourceRect = [System.Drawing.Rectangle]::new($rect.Left - $screenBounds.Left, $rect.Top - $screenBounds.Top, $width, $height)
    $targetRect = [System.Drawing.Rectangle]::new(0, 0, $width, $height)
    $graphics.DrawImage($screenBitmap, $targetRect, $sourceRect, [System.Drawing.GraphicsUnit]::Pixel)
    $graphics.Dispose()
    $screenBitmap.Dispose()
  }
  catch {
    $bitmap.Dispose()
    throw "Live capture failed for ${Path}: $($_.Exception.Message)"
  }

  if (Test-Path -LiteralPath $Path) {
    try {
      Remove-Item -LiteralPath $Path -Force
    }
    catch {
      $folder = Split-Path -Parent $Path
      $baseName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
      $Path = Join-Path $folder ($baseName + '-normal.png')
      if (Test-Path -LiteralPath $Path) {
        Remove-Item -LiteralPath $Path -Force
      }
    }
  }
  $stream = New-Object System.IO.MemoryStream
  try {
    $bitmap.Save($stream, [System.Drawing.Imaging.ImageFormat]::Png)
    [System.IO.File]::WriteAllBytes($Path, $stream.ToArray())
  }
  finally {
    $stream.Dispose()
  }
  $bitmap.Dispose()
}

$root = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $root 'bin\PackageStudioPro.exe'
$out = Join-Path $root 'docs\screenshots\PackageStudioPro'
New-Item -ItemType Directory -Force -Path $out | Out-Null

$process = Start-Process -FilePath $exe -PassThru
try {
  for ($i = 0; $i -lt 80 -and $process.MainWindowHandle -eq 0; $i++) {
    Start-Sleep -Milliseconds 250
    $process.Refresh()
  }
  if ($process.MainWindowHandle -eq 0) {
    throw 'PackageStudioPro window did not appear.'
  }

  $handle = [IntPtr]::Zero
  for ($i = 0; $i -lt 40 -and $handle -eq [IntPtr]::Zero; $i++) {
    $handle = Get-ProcessWindow -ProcessId $process.Id
    if ($handle -eq [IntPtr]::Zero) {
      Start-Sleep -Milliseconds 250
    }
  }
  if ($handle -eq [IntPtr]::Zero) {
    throw 'PackageStudioPro visible window was not found.'
  }
  $foregroundHandle = (Get-Process -Id $process.Id -ErrorAction Stop).MainWindowHandle
  if ($foregroundHandle -eq 0) {
    $foregroundHandle = $handle
  }
  [PspCaptureWin32]::ShowWindow($foregroundHandle, 5) | Out-Null
  [PspCaptureWin32]::SetForegroundWindow($foregroundHandle) | Out-Null
  Start-Sleep -Seconds 3

  $rect = New-Object PspCaptureWin32+RECT
  [PspCaptureWin32]::GetWindowRect($handle, [ref] $rect) | Out-Null
  if (($rect.Right - $rect.Left) -lt 200 -or ($rect.Bottom - $rect.Top) -lt 200) {
    [PspCaptureWin32]::GetWindowRect($foregroundHandle, [ref] $rect) | Out-Null
  }

  $tabs = @(
    @{ Name = 'product'; X = 38 },
    @{ Name = 'payload'; X = 95 },
    @{ Name = 'install'; X = 159 },
    @{ Name = 'integration'; X = 231 },
    @{ Name = 'build-review'; X = 323 }
  )

  foreach ($tab in $tabs) {
    [PspCaptureWin32]::SetCursorPos($rect.Left + $tab.X, $rect.Top + 133) | Out-Null
    Start-Sleep -Milliseconds 120
    [PspCaptureWin32]::mouse_event([PspCaptureWin32]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, [UIntPtr]::Zero)
    [PspCaptureWin32]::mouse_event([PspCaptureWin32]::MOUSEEVENTF_LEFTUP, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 500
    Capture-Window -Handle $handle -Path (Join-Path $out ("psp-$($tab.Name)-tab.png"))
  }
}
finally {
  if ($process -and -not $process.HasExited) {
    Stop-Process -Id $process.Id -Force
  }
}

Get-ChildItem -Path $out -Filter '*.png' | Select-Object Name, Length, LastWriteTime
