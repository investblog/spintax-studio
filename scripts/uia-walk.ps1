# uia-walk.ps1 -- what Windows' accessibility layer can actually see of this window.
#
# WHY THIS EXISTS. LCL has no accessibility bridge on the win32 widgetset: WM_GETOBJECT
# appears in win32proc.pp only as a message-name string for a debug log, and while
# TLazAccessibleObject is implemented for carbon, customdrawn, qt5 and qt6, there is no
# win32 implementation of it at all. So TControl.AccessibleName assigns, reads back
# correctly, and reaches nothing. That claim is worth nothing unmeasured, and this is the
# measurement: it walks the UI Automation tree the way a screen reader does and writes
# down what is there.
#
# Read the output against a control app before drawing a conclusion from it. The same
# walk over Notepad returns real roles, real names and focusable=True; if it ever stops
# doing that, the probe is broken and the baseline is measuring the probe.
#
# The output is a BASELINE, committed beside the code. A control that stops being
# focusable, or an item that goes back to reading as a bare tag, then shows up as a diff
# instead of as silence.
#
# NOT GATED IN CI, deliberately: a UIA walk needs an interactive desktop session and is
# timing-sensitive, and a flaky runner on a submission day is worse than no check. It
# prints its own diff instead.
#
# ASCII ONLY, no BOM. PowerShell 5.1 reads a BOM-less script as ANSI, so a non-ASCII
# character in this file arrives as mojibake and matches nothing.
#
#   .\scripts\uia-walk.ps1
#   .\scripts\uia-walk.ps1 -Baseline docs\accessibility-baseline.txt

param(
  [string]$Exe      = "",
  [string]$Out      = "",
  [string]$Baseline = "",
  [int]$WaitSeconds = 30
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ($Exe -eq '') { $Exe = Join-Path $root 'spintax-studio.exe' }
if ($Out -eq '') { $Out = Join-Path $root 'docs\accessibility-baseline.txt' }

if (-not (Test-Path $Exe)) { throw "no exe at $Exe -- run build.sh first" }

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes

$AE   = [System.Windows.Automation.AutomationElement]
$WALK = [System.Windows.Automation.TreeWalker]::ControlViewWalker

# The app writes its settings to a real folder in the user's profile, and a probe shares
# that file with the installed application. Move it aside so the walk starts from the
# app's own defaults, and put it back afterwards whatever happens.
$cfgDir  = Join-Path $env:LOCALAPPDATA 'spintax-studio'
$cfg     = Join-Path $cfgDir 'settings.txt'
$cfgSave = Join-Path $env:TEMP ('spx-settings-' + [System.Guid]::NewGuid().ToString('N') + '.bak')
$hadCfg  = Test-Path $cfg
# COPY, not move. The restore lives in a finally, which a Ctrl+C at the wrong moment or a
# killed console skips -- and a move would then have left the user's real preferences under a
# GUID in TEMP that nobody could guess. A copy costs nothing and the worst case is a stale
# duplicate.
if ($hadCfg) { Copy-Item $cfg $cfgSave -Force; Remove-Item $cfg -Force }

# Volatile text, masked so two runs of the same build compare equal. This runs over the
# Name column, which is the thing being measured -- so it masks as little as it can get
# away with: digits, and nothing else. The status bar reports a render time, and without
# this two runs of the same binary differ over four milliseconds.
function Mask([string]$s) {
  if ($null -eq $s) { return '' }
  $s = $s -replace "[`t`r`n]+", ' '
  # EVERY run of digits, not a list of units. The first attempt matched 'ms' and the status
  # bar says the same thing in fourteen languages -- it reported '17 mc' in Russian and the
  # two runs compared unequal over a render that took four milliseconds longer.
  $s = $s -replace '\d+([.,]\d+)?', '<n>'
  if ($s.Length -gt 60) { $s = $s.Substring(0, 60) + '...' }
  return $s
}

function Prop($el, $prop, $fallback) {
  try {
    $v = $el.GetCurrentPropertyValue($prop)
    if ($null -eq $v) { return $fallback }
    return $v
  } catch { return $fallback }
}

$lines = New-Object System.Collections.Generic.List[string]

function Walk($el, $depth) {
  try {
    $type  = (Prop $el $AE::ControlTypeProperty $null)
    $name  = if ($type) { $type.ProgrammaticName -replace '^ControlType\.', '' } else { '?' }
    $cls   = Prop $el $AE::ClassNameProperty ''
    $txt   = Mask (Prop $el $AE::NameProperty '')
    # LCL gives no AutomationId, so what arrives here is the window HANDLE, which is a
    # different number on every run. Keeping it would make the baseline compare unequal
    # to itself; dropping it loses nothing, because a handle identifies no control.
    $aid   = Prop $el $AE::AutomationIdProperty ''
    if ($aid -match '^\d+$') { $aid = '' }
    $focus = Prop $el $AE::IsKeyboardFocusableProperty $false
    $enab  = Prop $el $AE::IsEnabledProperty $false
    $off   = Prop $el $AE::IsOffscreenProperty $false
    $pad   = '  ' * $depth
    # Coordinates and sizes are deliberately absent: they move with the DPI and the window
    # size, and a baseline full of them is a baseline nobody can read a real change out of.
    $lines.Add(("{0}{1}`t{2}`t{3}`t{4}`tfocusable={5}`tenabled={6}`toffscreen={7}" -f `
                $pad, $name, $cls, $txt, $aid, $focus, $enab, $off))
  } catch {
    $lines.Add(('  ' * $depth) + '<element went away while being read>')
    return
  }
  try {
    $child = $WALK.GetFirstChild($el)
  } catch { return }
  while ($null -ne $child) {
    Walk $child ($depth + 1)
    try { $child = $WALK.GetNextSibling($child) } catch { break }
  }
}

$proc = $null
try {
  $proc = Start-Process -FilePath $Exe -PassThru
  # The main form's caption ENDS WITH the app name; LCL owns a second top-level window
  # titled exactly Application.Title, and matching that one would walk an empty shell.
  $hwnd = [IntPtr]::Zero
  $deadline = (Get-Date).AddSeconds($WaitSeconds)
  while ((Get-Date) -lt $deadline) {
    # Enumerate this process's top-level windows through UIA rather than through
    # MainWindowTitle, which reports whichever window Windows happens to hand back.
    $cond = New-Object System.Windows.Automation.PropertyCondition(
              $AE::ProcessIdProperty, $proc.Id)
    $found = $AE::RootElement.FindAll(
               [System.Windows.Automation.TreeScope]::Children, $cond)
    foreach ($c in $found) {
      $n = ''
      try { $n = $c.Current.Name } catch { continue }
      if ($n -like '*Spintax Studio' -and $n -ne 'Spintax Studio') {
        $hwnd = [IntPtr]$c.Current.NativeWindowHandle
        break
      }
    }
    if ($hwnd -ne [IntPtr]::Zero) { break }
    Start-Sleep -Milliseconds 400
  }
  if ($hwnd -eq [IntPtr]::Zero) { throw "the main window never appeared within $WaitSeconds s" }

  # Let the first render settle: the panels fill from a worker thread, and a walk that
  # starts too early photographs an empty diagnostics list.
  Start-Sleep -Milliseconds 1500
  $main = $AE::FromHandle($hwnd)

  $hdr = @()
  $hdr += '# Spintax Studio -- what UI Automation sees. Generated by scripts/uia-walk.ps1.'
  $hdr += '# Regenerate: .\scripts\uia-walk.ps1   Compare: .\scripts\uia-walk.ps1 -Baseline <file>'
  $hdr += ('# exe sha256:  ' + (Get-FileHash $Exe -Algorithm SHA256).Hash.ToLower())
  $hdr += ('# windows:     ' + [System.Environment]::OSVersion.Version.ToString())
  $hdr += ('# uia client:  ' + [System.Reflection.Assembly]::GetAssembly($AE).GetName().Version.ToString())
  $hdr += '#'
  $hdr += '# An empty name column on a row is the finding, not a gap in the probe: a control'
  $hdr += '# drawn by this application rather than by Windows has no name to give.'
  $hdr += ''

  Walk $main 0
  $all = $hdr + $lines
  [System.IO.File]::WriteAllLines($Out, $all, (New-Object System.Text.UTF8Encoding($false)))
  Write-Output ("wrote {0} ({1} elements)" -f $Out, $lines.Count)
}
finally {
  if ($proc -ne $null -and -not $proc.HasExited) {
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
  }
  Start-Sleep -Milliseconds 300
  if ($hadCfg) {
    if (-not (Test-Path $cfgDir)) { New-Item -ItemType Directory $cfgDir | Out-Null }
    Copy-Item $cfgSave $cfg -Force
    Remove-Item $cfgSave -Force -ErrorAction SilentlyContinue
  } elseif (Test-Path $cfg) {
    # There was no settings file before the run, so this one is the probe's own.
    Remove-Item $cfg -Force
  }
}

if ($Baseline -ne '') {
  if (-not (Test-Path $Baseline)) { throw "no baseline at $Baseline" }
  # The header carries a hash and an OS build, which differ by design on every rebuild.
  # -Encoding UTF8 is not optional: PowerShell 5.1 reads a file as the system ANSI codepage
  # by default, so every Cyrillic name arrives as mojibake and compares unequal to itself.
  $a = Get-Content $Baseline -Encoding UTF8 | Where-Object { $_ -notlike '#*' }
  $b = Get-Content $Out      -Encoding UTF8 | Where-Object { $_ -notlike '#*' }
  $diff = Compare-Object $a $b
  if ($null -eq $diff) {
    Write-Output 'accessible surface: unchanged'
  } else {
    Write-Output 'accessible surface CHANGED:'
    $diff | ForEach-Object { Write-Output ("  {0} {1}" -f $_.SideIndicator, $_.InputObject) }
    exit 1
  }
}
