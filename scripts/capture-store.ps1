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
# Two more levers exist since frames 07-09: a menu item fired by caption via WM_COMMAND
# (a menu is a walkable USER object, and its items answer without focus), and mouse
# messages sent to the child under a window-relative point. They reach STATE the window
# keeps once asked for -- the help, the group editor, the replace bar. An open menu
# itself and modal dialogs remain out of reach.
#
# WHAT THIS SCRIPT DOES NOT COVER: it assumes this machine's DPI. The window is placed
# at a fixed 1500x890, clickAt coordinates are unscaled window pixels, and Set-FindTexts
# recognises the find fields by a pixel height bound -- at another scale factor the
# coordinates land elsewhere. It is an instrument for this machine, not a portable tool.
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

# Fire a menu item by caption prefix, the way a reader would reach it. Menus are USER
# objects, readable and walkable from outside the process (GetMenu/GetSubMenu), and an
# LCL menu item answers WM_COMMAND with its id -- no focus, no foreground, no clicking.
# This is what makes the help panel, the group editor and the replace bar capturable:
# they are STATE once opened, not transient popups.
$WM_COMMAND = 0x0111
Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;
public class SpxMenu {
  [DllImport("user32.dll")] public static extern IntPtr GetMenu(IntPtr h);
  [DllImport("user32.dll")] public static extern int GetMenuItemCount(IntPtr m);
  [DllImport("user32.dll")] public static extern IntPtr GetSubMenu(IntPtr m, int pos);
  [DllImport("user32.dll")] public static extern uint GetMenuItemID(IntPtr m, int pos);
  [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetMenuStringW(IntPtr m, uint pos, StringBuilder s, int n, uint flags);
  [DllImport("user32.dll")] public static extern bool PostMessageW(IntPtr h, uint msg, IntPtr wp, IntPtr lp);
  [DllImport("user32.dll")] public static extern bool RedrawWindow(IntPtr h, IntPtr rect, IntPtr rgn, uint flags);
}
"@
function Invoke-MenuItem($hwnd, [string]$prefix) {
  $bar = [SpxMenu]::GetMenu($hwnd)
  if ($bar -eq [IntPtr]::Zero) { Write-Host '  (window has no menu bar)'; return $false }
  $MF_BYPOSITION = 0x400
  for ($i = 0; $i -lt [SpxMenu]::GetMenuItemCount($bar); $i++) {
    $sub = [SpxMenu]::GetSubMenu($bar, $i)
    if ($sub -eq [IntPtr]::Zero) { continue }
    for ($j = 0; $j -lt [SpxMenu]::GetMenuItemCount($sub); $j++) {
      $sb = New-Object System.Text.StringBuilder 256
      [void][SpxMenu]::GetMenuStringW($sub, $j, $sb, 256, $MF_BYPOSITION)
      # the caption carries the shortcut after a tab; match the caption half only
      $cap = ($sb.ToString() -split "`t")[0]
      if ($cap.StartsWith($prefix)) {
        $id = [SpxMenu]::GetMenuItemID($sub, $j)
        if ($id -ne 0 -and $id -ne 4294967295) {
          return [SpxMenu]::PostMessageW($hwnd, $WM_COMMAND, [IntPtr][int64]$id, [IntPtr]::Zero)
        }
      }
    }
  }
  Write-Host ("  (no menu item starting '{0}')" -f $prefix)
  return $false
}

# Fill the find bar's two fields. After the Replace menu item opens the two-row bar, the
# top strip owns exactly two small single-line EDITs on the template half -- the needle
# above the replacement -- and WM_SETTEXT into a native EDIT fires the same change event
# typing would, so the counter beside the field updates itself.
function Set-FindTexts($hwnd, [string]$needle, [string]$replacement) {
  $edits = Get-Children $hwnd |
           Where-Object { $_.cls -eq 'Edit' -and $_.vis -and $_.ht -lt 40 } |
           Sort-Object y
  if ($edits.Count -lt 2) { Write-Host '  (replace bar fields not found)'; return $false }
  [void][SpxCap]::SendMessageW($edits[0].h, $WM_SETTEXT, [IntPtr]::Zero, $needle)
  Start-Sleep -Milliseconds 300
  [void][SpxCap]::SendMessageW($edits[1].h, $WM_SETTEXT, [IntPtr]::Zero, $replacement)
  return $true
}

# Click a point given in WINDOW coordinates. Finds the deepest visible child under the
# point and sends move+down+up with that child's client coordinates -- IPro decides which
# link is hot on the MOVE, so the move is not optional. This is what runs a help example:
# the template half of every example is a link, and clicking it renders it on the right.
function Invoke-ClickAt($hwnd, [int]$wx, [int]$wy) {
  $r = New-Object SpxCap+RECT
  [void][SpxCap]::GetWindowRect($hwnd, [ref]$r)
  $sx = $r.L + $wx; $sy = $r.T + $wy
  # EnumChildWindows lists parents before children, so among the equal-rect stacked LCL
  # containers the LAST is the deepest -- and the deepest is the one whose handler acts.
  # Click every enclosing candidate deepest-first; a container that ignores the click is
  # harmless, and measuring which of four identical rects is the real control is not
  # possible from outside.
  $cands = @(Get-Children $hwnd | Where-Object {
    $_.vis -and $sx -ge $_.x -and $sx -lt ($_.x + $_.w) -and $sy -ge $_.y -and $sy -lt ($_.y + $_.ht)
  })
  if ($cands.Count -eq 0) { Write-Host '  (no child under click point)'; return $false }
  [array]::Reverse($cands)
  $WM_MOUSEMOVE = 0x0200; $WM_LBUTTONDOWN = 0x0201; $WM_LBUTTONUP = 0x0202
  foreach ($t in $cands) {
    $cx = $sx - $t.x; $cy = $sy - $t.y
    $lp = [IntPtr](($cy -shl 16) -bor ($cx -band 0xFFFF))
    [void][SpxCap]::SendMessageW($t.h, $WM_MOUSEMOVE, [IntPtr]::Zero, $lp)
    Start-Sleep -Milliseconds 200
    [void][SpxCap]::SendMessageW($t.h, $WM_LBUTTONDOWN, [IntPtr][int]1, $lp)
    Start-Sleep -Milliseconds 100
    [void][SpxCap]::SendMessageW($t.h, $WM_LBUTTONUP, [IntPtr]::Zero, $lp)
    Start-Sleep -Milliseconds 400
  }
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
     drive = 'ai'; applyClick = 'Replace the document';
     what = 'the AI loop complete: plain text in the brief, the draft applied, its render live' }
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
  # The three below need a menu command after launch -- state the window keeps once asked
  # for, reached by WM_COMMAND rather than a click (menus are walkable USER objects).
  @{ name = '07-help';            theme = 'light'; panel = -1; doc = 'tour.spintax';   src = 'no';
     menu = 'Contents'; afterMenuMs = 2000; clickAt = @(,@(60, 333)) + @(,@(340, 176));
     what = 'the built-in help on the Choices chapter, a clicked example rendered live' }
  @{ name = '08-replace';         theme = 'light'; panel = -1; doc = 'tour.spintax';   src = 'no';
     menu = 'Replace'; find = 'session'; replaceWith = 'meeting'; afterMenuMs = 1200;
     what = 'find and replace: the two-row bar with the match counter' }
  @{ name = '09-dark-group';      theme = 'dark';  panel = -1; doc = 'group.spintax';  src = 'no';
     menu = 'Group under the caret'; afterMenuMs = 1500;
     what = 'the group editor slid out beside the caret, alternatives editable' }
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

      if ($frame.menu) {
        # Each setup step is FATAL on failure: a frame whose menu item or click target
        # was not found would still photograph at the right size, and the size check at
        # the end is the only other gate -- a wrong screenshot must not exit 0.
        if (-not (Invoke-MenuItem $hwnd $frame.menu)) {
          throw ("frame {0}: menu item '{1}' not found" -f $frame.name, $frame.menu)
        }
        $afterM = 1500
        if ($frame.afterMenuMs) { $afterM = [int]$frame.afterMenuMs }
        Start-Sleep -Milliseconds $afterM
        if ($frame.find) {
          if (-not (Set-FindTexts $hwnd $frame.find $frame.replaceWith)) {
            throw ("frame {0}: replace bar fields not found" -f $frame.name)
          }
          Start-Sleep -Milliseconds 900
        }
        if ($frame.clickAt) {
          foreach ($pt in $frame.clickAt) {
            if (-not (Invoke-ClickAt $hwnd $pt[0] $pt[1])) {
              throw ("frame {0}: no child under click point ({1},{2})" -f $frame.name, $pt[0], $pt[1])
            }
            Start-Sleep -Milliseconds 1500
          }
        }
        # A layout switch can leave the IPro preview unpainted (its EraseBackground is
        # empty and it has no resize handler) -- ask the whole tree to repaint before
        # the photograph, or the right pane comes out white.
        [void][SpxMenu]::RedrawWindow($hwnd, [IntPtr]::Zero, [IntPtr]::Zero, 0x0187)
        Start-Sleep -Milliseconds 600
      }

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
        # And APPLY the draft: with the document and the brief holding the same plain
        # text, the frame read as if the editor's text had been sent to the model --
        # the owner mistook it for exactly that. Pressing Replace puts the GENERATED
        # TEMPLATE in the editor and its render in the preview, so the frame shows the
        # whole loop and the editor no longer mirrors the brief.
        if ($frame.applyClick) {
          [void](Invoke-Button $hwnd $frame.applyClick)
          Start-Sleep -Milliseconds 2000
        }
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

