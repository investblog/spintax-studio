# probe-children.ps1 -- what native child windows this form actually owns.
#
# UI Automation sees nothing usable here (docs/accessibility-baseline.txt), but LCL draws
# on the win32 widgetset, so a TButton is a real BUTTON window with a caption and a
# TMemo is a real EDIT. If that holds, a capture script can fill a field with WM_SETTEXT
# and press a button with BM_CLICK -- neither of which needs the foreground, which this
# kind of session cannot take.
#
# This probe answers whether that is true before any capture depends on it.
#
# ASCII ONLY, no BOM.
#
#   .\scripts\probe-children.ps1 -Doc scripts\store-fixtures\brief.spintax -Panel 3

param(
  [string]$Exe   = "",
  [string]$Doc   = "",
  [int]$Panel    = 3,
  [int]$WaitSeconds = 30,
  [int]$SettleMs    = 2200
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ($Exe -eq '') { $Exe = Join-Path $root 'spintax-studio.exe' }
if ($Doc -eq '') { $Doc = Join-Path $PSScriptRoot 'store-fixtures\brief.spintax' }

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes
$AE = [System.Windows.Automation.AutomationElement]

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class SpxProbe {
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@

$cfgDir = Join-Path $env:LOCALAPPDATA 'spintax-studio'
$cfg    = Join-Path $cfgDir 'settings.txt'
$save   = Join-Path $env:TEMP ('spx-probe-' + [System.Guid]::NewGuid().ToString('N') + '.bak')
$had    = Test-Path $cfg
if ($had) { Copy-Item $cfg $save -Force }

$proc = $null
try {
  $carried = @()
  if ($had) { $carried = Get-Content $save -Encoding UTF8 | Where-Object { $_ -match '^\s*ai\.' } }
  $lines = @('lang=en', 'lang.follow=no', 'theme=light', ('panel=' + $Panel)) + $carried
  New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
  [System.IO.File]::WriteAllLines($cfg, $lines, (New-Object System.Text.UTF8Encoding($false)))

  $proc = Start-Process -FilePath $Exe -ArgumentList "`"$Doc`"" -PassThru
  $hwnd = [IntPtr]::Zero
  $deadline = (Get-Date).AddSeconds($WaitSeconds)
  while ((Get-Date) -lt $deadline) {
    $cond  = New-Object System.Windows.Automation.PropertyCondition($AE::ProcessIdProperty, $proc.Id)
    $found = $AE::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
    foreach ($c in $found) {
      $n = ''
      try { $n = $c.Current.Name } catch { continue }
      if ($n -like '*Spintax Studio' -and $n -ne 'Spintax Studio') { $hwnd = [IntPtr]$c.Current.NativeWindowHandle; break }
    }
    if ($hwnd -ne [IntPtr]::Zero) { break }
    Start-Sleep -Milliseconds 400
  }
  if ($hwnd -eq [IntPtr]::Zero) { throw 'main window never appeared' }
  Start-Sleep -Milliseconds $SettleMs

  $rows = New-Object System.Collections.Generic.List[string]
  $cb = [SpxProbe+EnumProc]{
    param($h, $p)
    $cls = New-Object System.Text.StringBuilder 256
    $txt = New-Object System.Text.StringBuilder 256
    [void][SpxProbe]::GetClassNameW($h, $cls, 256)
    [void][SpxProbe]::GetWindowTextW($h, $txt, 256)
    $r = New-Object SpxProbe+RECT
    [void][SpxProbe]::GetWindowRect($h, [ref]$r)
    $vis = [SpxProbe]::IsWindowVisible($h)
    # Position matters as much as size: three same-shaped memos sit side by side in the AI
    # pane and only their left edge says which is "text to convert" and which is the answer.
    $rows.Add(("0x{0:X8}  {1,-16} vis={2,-5} @{3,5},{4,-5} {5,4}x{6,-4}  {7}" -f `
               [int64]$h, $cls.ToString(), $vis, $r.L, $r.T, ($r.R-$r.L), ($r.B-$r.T), $txt.ToString()))
    return $true
  }
  [void][SpxProbe]::EnumChildWindows($hwnd, $cb, [IntPtr]::Zero)

  Write-Output ("{0} child windows" -f $rows.Count)
  $rows | ForEach-Object { Write-Output $_ }
}
finally {
  if ($proc -ne $null -and -not $proc.HasExited) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
  Start-Sleep -Milliseconds 300
  if ($had) { Copy-Item $save $cfg -Force; Remove-Item $save -Force -ErrorAction SilentlyContinue }
  elseif (Test-Path $cfg) { Remove-Item $cfg -Force }
}
