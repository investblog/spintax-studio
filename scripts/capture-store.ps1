# capture-store.ps1 -- Store listing frames, captured from the real executable.
#
# WHY NOT THE SCREENSHOT PIPELINE NEXT DOOR. W:\projects\temp_scr drives Chromium in
# Docker under Xvfb: it exists to photograph browser extensions. This is a native LCL
# window, so none of that applies and the capture belongs here, beside the probe that
# already knows how to launch this exe and how to find its window.
#
# HOW A FRAME IS SET UP. Not by clicking: UI Automation sees nothing usable in this
# window (docs/accessibility-baseline.txt is a wall of nameless Panes with
# focusable=False), and this session cannot take the foreground at all. Every frame is
# therefore reachable from state the application reads at startup:
#   - theme, language, which bottom panel is open, the preview face, panel widths
#     come from %LOCALAPPDATA%\spintax-studio\settings.txt
#   - the document comes from ParamStr(1) (SpxMainForm.pas:692)
# A frame that needs transient UI -- an open menu, the find bar -- has no lever here and
# is deliberately not in the set.
#
# CAPTURE IS PrintWindow(hwnd, dc, PW_RENDERFULLCONTENT). GetFormImage and PaintTo cannot
# photograph a windowed child: a combo box or any TCustomControl comes out blank, and the
# result is evidence about the parent instead of the control. PrintWindow needs the window
# to exist, not to be in front -- which is the only reason this works, because
# SetForegroundWindow, AppActivate and a synthetic title-bar click were all measured from a
# session like this one and all refused.
#
# THE SETTINGS FILE IS THE USER'S. It is copied aside and restored in a finally, and the
# ai.* profile lines are carried through unchanged so the AI frame shows a real attached
# key. That is safe on purpose: SpxLlmKeyHint renders start + ellipsis + last four, the
# field is write-only, and the source calls the result "the dashboard fragment,
# recognisable and unusable" (gui/SpxAiPane.pas:921).
#
# ASCII ONLY, no BOM -- PowerShell 5.1 reads a BOM-less script as ANSI, so a non-ASCII
# character here arrives as mojibake and matches nothing.
#
#   .\scripts\capture-store.ps1
#   .\scripts\capture-store.ps1 -Only 03-ai,04-dark-variants
#   .\scripts\capture-store.ps1 -Width 1500 -Height 890

param(
  [string]$Exe    = "",
  [string]$OutDir = "",
  [int]$Width     = 1500,
  [int]$Height    = 890,
  [string[]]$Only = @(),
  [int]$WaitSeconds   = 30,
  [int]$SettleMs      = 2200,
  [int]$AiTimeoutSec  = 90
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
if ($Exe    -eq '') { $Exe    = Join-Path $root 'spintax-studio.exe' }
if ($OutDir -eq '') { $OutDir = Join-Path $root 'build\store-submission' }
if (-not (Test-Path $Exe)) { throw "no exe at $Exe -- run build.sh first" }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

Add-Type -AssemblyName UIAutomationClient, UIAutomationTypes, System.Drawing
$AE = [System.Windows.Automation.AutomationElement]

Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class SpxCap {
  public delegate bool EnumProc(IntPtr h, IntPtr p);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr dc, uint f);
  [DllImport("user32.dll")] public static extern bool MoveWindow(IntPtr h, int x, int y, int w, int t, bool r);
  [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
  [DllImport("user32.dll")] public static extern bool EnumChildWindows(IntPtr h, EnumProc cb, IntPtr p);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr h, StringBuilder s, int n);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, string l);
  [DllImport("user32.dll")] public static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, IntPtr l);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr SendMessageW(IntPtr h, uint m, IntPtr w, StringBuilder l);
  [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L, T, R, B; }
}
"@

# LCL draws on the win32 widgetset, so a TButton IS a native BUTTON with a caption and a
# TMemo IS a native EDIT. That is the whole reason the AI frame can be driven: BM_CLICK and
# WM_SETTEXT are messages, and a message does not need the foreground -- which this kind of
# session cannot take. UI Automation, by contrast, sees only nameless Panes here.
$WM_SETTEXT = 0x000C
$WM_GETTEXT = 0x000D
$WM_GETTEXTLENGTH = 0x000E
$BM_CLICK   = 0x00F5

function Get-Children($hwnd) {
  $out = New-Object System.Collections.Generic.List[object]
  $cb = [SpxCap+EnumProc]{
    param($h, $p)
    $cls = New-Object System.Text.StringBuilder 256
    $txt = New-Object System.Text.StringBuilder 512
    [void][SpxCap]::GetClassNameW($h, $cls, 256)
    [void][SpxCap]::GetWindowTextW($h, $txt, 512)
    $r = New-Object SpxCap+RECT
    [void][SpxCap]::GetWindowRect($h, [ref]$r)
    $out.Add([pscustomobject]@{
      h = $h; cls = $cls.ToString(); text = $txt.ToString()
      vis = [SpxCap]::IsWindowVisible($h)
      x = $r.L; y = $r.T; w = ($r.R - $r.L); ht = ($r.B - $r.T)
    })
    return $true
  }
  [void][SpxCap]::EnumChildWindows($hwnd, $cb, [IntPtr]::Zero)
  return $out
}

function Get-ControlText($h) {
  $n = [int][SpxCap]::SendMessageW($h, $WM_GETTEXTLENGTH, [IntPtr]::Zero, [IntPtr]::Zero)
  if ($n -le 0) { return '' }
  $sb = New-Object System.Text.StringBuilder ($n + 2)
  [void][SpxCap]::SendMessageW($h, $WM_GETTEXT, [IntPtr]($n + 1), $sb)
  return $sb.ToString()
}

# Press a visible button by its caption. Two panels own a button captioned Generate (the
# variants list and the AI pane) and only the open panel's copy is visible, so visibility
# is the disambiguator rather than any index.
function Invoke-Button($hwnd, [string]$caption) {
  $btn = Get-Children $hwnd |
         Where-Object { $_.cls -eq 'Button' -and $_.vis -and $_.text -eq $caption } |
         Select-Object -First 1
  if ($null -eq $btn) { Write-Host ("  (no visible button captioned '{0}')" -f $caption); return $false }
  [void][SpxCap]::SendMessageW($btn.h, $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)
  return $true
}

# Fill the brief and press Generate, so the headline frame shows the feature WORKING rather
# than an empty pane. The two tall visible EDITs in the AI page are the brief on the left
# and the model's answer on the right; there are two buttons captioned Generate in the
# application (the variants panel owns the other) and only the AI one is visible here.
function Invoke-AiDraft($hwnd, [string]$brief, [int]$timeoutSec) {
  $kids  = Get-Children $hwnd
  $memos = $kids | Where-Object { $_.cls -eq 'Edit' -and $_.vis -and $_.ht -ge 60 } | Sort-Object x
  $btn   = $kids | Where-Object { $_.cls -eq 'Button' -and $_.vis -and $_.text -eq 'Generate' } | Select-Object -First 1
  if ($memos.Count -lt 2 -or $null -eq $btn) {
    # Write-Host, not Write-Output: the caller discards this function's pipeline output,
    # and progress that only the pipeline carries would vanish with it.
    Write-Host '  (AI pane not laid out as expected -- capturing it idle)'
    return $false
  }
  $inBox  = $memos[0]
  $outBox = $memos[-1]

  # CRLF, not LF. A native EDIT treats a bare LF as nothing, so the fixture's line breaks
  # disappeared and the box read "every Tuesdaymorning" -- words welded together in a frame
  # meant for a store listing.
  $brief = $brief -replace "`r`n", "`n" -replace "`n", "`r`n"
  [void][SpxCap]::SendMessageW($inBox.h, $WM_SETTEXT, [IntPtr]::Zero, $brief)
  Start-Sleep -Milliseconds 400
  [void][SpxCap]::SendMessageW($btn.h, $BM_CLICK, [IntPtr]::Zero, [IntPtr]::Zero)

  $deadline = (Get-Date).AddSeconds($timeoutSec)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 700
    $answer = Get-ControlText $outBox.h
    if ($answer.Trim().Length -gt 0) {
      Write-Host ('  model answered, {0} chars' -f $answer.Trim().Length)
      Start-Sleep -Milliseconds 900   # let the pane finish painting the text
      return $true
    }
  }
  Write-Host '  (no answer within the timeout -- capturing whatever the pane shows)'
  return $false
}

# --- the frames -------------------------------------------------------------------
# Bottom panel indices are the tab order in SpxMainForm.pas:946-952 --
#   0 diagnostics, 1 variables, 2 variants, 3 AI; -1 collapses the block.
$FRAMES = @(
  @{ name = '01-editor';          theme = 'light'; panel = -1; doc = 'tour.spintax';   src = 'no';
     what = 'the two-pane shape: template on the left, live render on the right' }
  @{ name = '02-diagnostics';     theme = 'light'; panel = 0;  doc = 'broken.spintax'; src = 'no';
     what = 'a real syntax error with its source position and the engine diagnostic' }
  @{ name = '03-ai';              theme = 'light'; panel = 3;  doc = 'brief.spintax';  src = 'no';
     drive = 'ai';
     what = 'the optional AI draft panel, disclosed, with an attached key shown masked' }
  @{ name = '04-dark-variants';   theme = 'dark';  panel = 2;  doc = 'tour.spintax';   src = 'no';
     click = 'Generate'; afterClickMs = 2500;
     what = 'generated variants with the seed and the export actions' }
  # The variables panel was the obvious fifth frame and is NOT here on purpose: its
  # Definitions section sits collapsed behind a splitter that no setting carries, so the
  # capture reads as an empty panel however long it settles, and a splitter needs a mouse
  # drag this session cannot perform. Listing bullet 16 sells the fourteen interface
  # languages, and that one IS reachable from settings -- so it takes the slot.
  # The variants panel, not diagnostics, for the language frame. Diagnostics wording follows
  # the DOCUMENT language rather than the interface, so a German window showed German column
  # headings over English messages -- honest, but it reads as half-finished localisation in a
  # storefront. The variants panel translates completely, because its content is numbers and
  # the document's own text.
  @{ name = '05-dark-german';     theme = 'dark';  panel = 2;  doc = 'tour.spintax';   src = 'no';
     lang = 'de'; click = 'Erzeugen'; afterClickMs = 2500;
     what = 'the same window in German - one of the fourteen interface languages' }
  @{ name = '06-dark-source';     theme = 'dark';  panel = -1; doc = 'tour.spintax';   src = 'yes';
     what = 'the preview showing rendered source rather than the page' }
)

# --- settings, borrowed and returned ----------------------------------------------
$cfgDir  = Join-Path $env:LOCALAPPDATA 'spintax-studio'
$cfg     = Join-Path $cfgDir 'settings.txt'
$cfgSave = Join-Path $env:TEMP ('spx-capture-' + [System.Guid]::NewGuid().ToString('N') + '.bak')
$hadCfg  = Test-Path $cfg
# COPY, not move: the restore lives in a finally, which a Ctrl+C skips, and a move would
# leave the reader's real preferences under a GUID in TEMP that nobody could guess.
if ($hadCfg) { Copy-Item $cfg $cfgSave -Force }

function Write-Frame-Settings($frame) {
  # Carry the ai.* profile through untouched -- that is what makes the AI frame show a
  # real attached key rather than an empty pane. Everything else is ours to set.
  $carried = @()
  if ($hadCfg) {
    $carried = Get-Content $cfgSave -Encoding UTF8 | Where-Object { $_ -match '^\s*ai\.' }
  }
  $lang = 'en'   # the listing language, unless a frame is about the language itself
  if ($frame.lang) { $lang = $frame.lang }
  $lines = @(
    '# written by scripts/capture-store.ps1 -- the reader''s own file is restored afterwards'
    ('lang=' + $lang)
    'lang.follow=no'   # off, so a document cannot change the interface language mid-capture
    ('theme=' + $frame.theme)
    ('panel=' + $frame.panel)
    ('preview.source=' + $frame.src)
    'rail.right=no'
    'gsa.import=no'
    'font.family=Consolas'
    'font.size=14'
    'slide.width=300'
    'help.width=260'
  ) + $carried
  New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
  [System.IO.File]::WriteAllLines($cfg, $lines, (New-Object System.Text.UTF8Encoding($false)))
}

function Find-MainWindow($procId) {
  # The main form's caption ENDS WITH the app name; LCL owns a second top-level window
  # titled exactly Application.Title, and matching that one photographs an empty shell.
  $deadline = (Get-Date).AddSeconds($WaitSeconds)
  while ((Get-Date) -lt $deadline) {
    $cond = New-Object System.Windows.Automation.PropertyCondition($AE::ProcessIdProperty, $procId)
    $found = $AE::RootElement.FindAll([System.Windows.Automation.TreeScope]::Children, $cond)
    foreach ($c in $found) {
      $n = ''
      try { $n = $c.Current.Name } catch { continue }
      if ($n -like '*Spintax Studio' -and $n -ne 'Spintax Studio') {
        $h = [IntPtr]$c.Current.NativeWindowHandle
        if ($h -ne [IntPtr]::Zero -and [SpxCap]::IsWindowVisible($h)) { return $h }
      }
    }
    Start-Sleep -Milliseconds 400
  }
  return [IntPtr]::Zero
}

function Capture-Window($hwnd, $path) {
  $r = New-Object SpxCap+RECT
  [void][SpxCap]::GetWindowRect($hwnd, [ref]$r)
  $w = $r.R - $r.L; $h = $r.B - $r.T
  if ($w -le 0 -or $h -le 0) { throw "window has no size ($w x $h)" }
  $bmp = New-Object System.Drawing.Bitmap($w, $h)
  $g   = [System.Drawing.Graphics]::FromImage($bmp)
  $dc  = $g.GetHdc()
  try {
    # PW_RENDERFULLCONTENT (2). Without it a composited child renders black.
    $ok = [SpxCap]::PrintWindow($hwnd, $dc, 2)
    if (-not $ok) { throw 'PrintWindow refused' }
  } finally { $g.ReleaseHdc($dc); $g.Dispose() }
  $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
  $size = "$($bmp.Width)x$($bmp.Height)"
  $bmp.Dispose()
  return $size
}

$fixtures = Join-Path $PSScriptRoot 'store-fixtures'
$done = @()

try {
  foreach ($frame in $FRAMES) {
    if ($Only.Count -gt 0 -and ($Only -notcontains $frame.name)) { continue }
    $doc = Join-Path $fixtures $frame.doc
    if (-not (Test-Path $doc)) { throw "no fixture at $doc" }

    Write-Frame-Settings $frame
    $proc = $null
    try {
      $proc = Start-Process -FilePath $Exe -ArgumentList "`"$doc`"" -PassThru
      $hwnd = Find-MainWindow $proc.Id
      if ($hwnd -eq [IntPtr]::Zero) { throw "the main window never appeared within $WaitSeconds s" }

      [void][SpxCap]::MoveWindow($hwnd, 60, 60, $Width, $Height, $true)
      # The panels fill from a worker thread; a capture that starts too early photographs
      # an empty diagnostics list. The resize also has to repaint before it is read.
      Start-Sleep -Milliseconds $SettleMs

      if ($frame.click) {
        [void](Invoke-Button $hwnd $frame.click)
        $after = 1500
        if ($frame.afterClickMs) { $after = [int]$frame.afterClickMs }
        Start-Sleep -Milliseconds $after
      }

      if ($frame.drive -eq 'ai') {
        # The brief is the fixture's own text: the frame then shows one document turned
        # into a template by the feature the listing leads with.
        $brief = (Get-Content $doc -Raw -Encoding UTF8).Trim()
        [void](Invoke-AiDraft $hwnd $brief $AiTimeoutSec)
      }

      $out = Join-Path $OutDir ('spintax-' + $frame.name + '.png')
      $size = Capture-Window $hwnd $out
      $done += [pscustomobject]@{ frame = $frame.name; size = $size; file = $out }
      Write-Output ("{0,-20} {1,-10} {2}" -f $frame.name, $size, $frame.what)
    }
    finally {
      if ($proc -ne $null -and -not $proc.HasExited) {
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
      }
      Start-Sleep -Milliseconds 400
    }
  }
}
finally {
  if ($hadCfg) {
    New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
    Copy-Item $cfgSave $cfg -Force
    Remove-Item $cfgSave -Force -ErrorAction SilentlyContinue
  } elseif (Test-Path $cfg) {
    Remove-Item $cfg -Force   # there was none before; this one is the probe's own
  }
}

Write-Output ''
Write-Output ("{0} frame(s) -> {1}" -f $done.Count, $OutDir)
$wrong = $done | Where-Object { $_.size -ne ("{0}x{1}" -f $Width, $Height) }
if ($wrong) {
  Write-Output 'SIZE MISMATCH -- the Store listing expects every frame at one size:'
  $wrong | ForEach-Object { Write-Output ("  {0}  {1}" -f $_.frame, $_.size) }
  exit 1
}

