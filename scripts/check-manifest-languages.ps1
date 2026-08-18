# check-manifest-languages.ps1 -- will Windows actually register a package that declares these
# languages?
#
# WHY THIS EXISTS. `<Resource Language="sr" />` shipped in 0.2.0.0 and made the package
# impossible to install. Windows refuses to register a package whose resource language is a
# script required language written without its script, and reports it as 0x80073CF6 wrapping
# 0x80070057, "the specified resource language is invalid". Every gate this project had was
# green: the suite compared the list against gui/lang/, WACK passed against the tag's artefact,
# and Store certification accepted the submission, because certification reads the manifest
# schema and never calls Add-AppxPackage. The first reader to press Get in the Store got the
# Store's own "Something went wrong" and the live product was uninstallable for three days.
#
# So this is the gate BETWEEN the manifest and the thing that will consume it. It reads the
# tags out of the template, builds a minimal package that declares exactly those tags and
# nothing else of ours, and asks Windows to register it. Nothing here is a copy of a rule about
# which tags are valid: the deployment stack answers, which is the whole point, and it will go
# on answering when Microsoft changes its mind.
#
# WHAT IT DOES NOT COVER. It answers only "will this register", on THIS Windows. It knows
# nothing about whether a tag is one the Store publishes or whether it names the right script
# for the window -- both of those are in the suite (CheckManifestLanguages), and neither of them
# can see this failure. It also does not build the real package: the payload is a stub, because
# what is on trial is the language list.
#
# It needs Developer Mode, and it FAILS rather than skips without it. A leg that silently skips
# is how the original gap survived, so the absence of the setting is reported by name.

[CmdletBinding()]
param(
  [string] $Manifest = "packaging/AppxManifest.xml.in"
)

$ErrorActionPreference = 'Stop'
$probeName = 'SpxManifestLangProbe'

function Fail($msg) { Write-Host "FAIL  $msg"; exit 1 }

if (-not (Test-Path $Manifest)) { Fail "manifest not found: $Manifest" }

# PARSED AS XML, NOT MATCHED BY PATTERN. The first version of this script used a regex
# demanding `Language="` exactly, and it was wrong in both directions, measured: it read a
# `<Resource ... />` quoted inside an XML COMMENT as a live declaration, and it could not see
# `Language = 'sr'`, which XML allows and MakeAppx and the deployment stack both accept. With a
# good `sr-Cyrl` also present, that combination reported OK over a manifest carrying the very
# tag this gate exists to catch. The template's @NAME@ placeholders are legal inside attribute
# values, so the document parses as it stands.
$text = Get-Content -Raw -Encoding UTF8 $Manifest
try { $xml = [xml] $text }
catch { Fail "$Manifest does not parse as XML: $($_.Exception.Message)" }

$nodes = @($xml.Package.Resources.Resource)
if ($nodes.Count -eq 0) { Fail "no <Resource> elements inside <Resources> in $Manifest" }

# An element without a readable Language is a finding, not something to step over quietly.
$blank = @($nodes | Where-Object { [string]::IsNullOrWhiteSpace($_.Language) })
if ($blank.Count -gt 0) { Fail "$($blank.Count) <Resource> element(s) carry no Language attribute" }

$tags = @($nodes | ForEach-Object { $_.Language })
Write-Host "declared: $($tags -join ', ')"

$devMode = $null
try {
  $devMode = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppModelUnlock' `
              -ErrorAction Stop).AllowDevelopmentWithoutDevLicense
} catch { }
if ($devMode -ne 1) {
  Fail ("Developer Mode is off (AppModelUnlock\AllowDevelopmentWithoutDevLicense is " +
        "'$devMode'), so a loose package cannot be registered and this check cannot run. " +
        "Enable it rather than skipping: skipping is how the defect this gate exists for " +
        "reached the Store.")
}

$work = Join-Path ([System.IO.Path]::GetTempPath()) "spx-langprobe-$PID"
$null = New-Item -ItemType Directory -Force -Path (Join-Path $work 'Assets')

try {
  # A one pixel PNG is enough for every logo the manifest must name; nothing renders it.
  $png = [Convert]::FromBase64String(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==')
  foreach ($n in 'StoreLogo.png','Square150x150Logo.png','Square44x44Logo.png') {
    [IO.File]::WriteAllBytes((Join-Path $work "Assets\$n"), $png)
  }
  # An executable that is never launched; registration only requires the file to be there.
  Copy-Item "$env:SystemRoot\System32\cmd.exe" (Join-Path $work 'app.exe')

  $res = ($tags | ForEach-Object { "    <Resource Language=`"$_`" />" }) -join "`n"
  $xml = @"
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
         IgnorableNamespaces="uap rescap">
  <Identity Name="$probeName" Publisher="CN=$probeName" Version="1.0.0.0" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>$probeName</DisplayName>
    <PublisherDisplayName>probe</PublisherDisplayName>
    <Logo>Assets\StoreLogo.png</Logo>
  </Properties>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.22621.0" />
  </Dependencies>
  <Resources>
$res
  </Resources>
  <Applications>
    <Application Id="Probe" Executable="app.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="$probeName" Description="probe"
        Square150x150Logo="Assets\Square150x150Logo.png" Square44x44Logo="Assets\Square44x44Logo.png"
        BackgroundColor="transparent" />
    </Application>
  </Applications>
  <Capabilities>
    <rescap:Capability Name="runFullTrust" />
  </Capabilities>
</Package>
"@
  [IO.File]::WriteAllText((Join-Path $work 'AppxManifest.xml'), $xml, (New-Object Text.UTF8Encoding $false))

  try { Add-AppxPackage -Register (Join-Path $work 'AppxManifest.xml') -ErrorAction Stop }
  catch {
    $m = ($_.Exception.Message -replace '\s+', ' ')
    Fail ("Windows refuses to register a package declaring these languages. " +
          "This is what a reader sees as the Store's `"Something went wrong`". $m")
  }
  Write-Host "OK    Windows registered a package declaring all $($tags.Count) languages"
}
finally {
  $p = Get-AppxPackage -Name $probeName -ErrorAction SilentlyContinue
  if ($p) { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction SilentlyContinue }
  Remove-Item -Recurse -Force $work -ErrorAction SilentlyContinue
}
