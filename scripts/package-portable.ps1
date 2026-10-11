# Package a multi-file, no-install PulseForge distribution for Windows 11 x64.
# Keep the compiled desktop EXE, FFmpeg tools, launcher and portable data folder together.
param(
  [string] $ArtifactRoot = ""
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path

if ([string]::IsNullOrWhiteSpace($ArtifactRoot)) {
  $ArtifactRoot = Join-Path $repoRoot 'portable-dist'
}

$appExe = Join-Path $repoRoot 'app\src-tauri\target\release\pulseforge.exe'
$ffmpegExe = Join-Path $repoRoot 'app\src-tauri\bin\ffmpeg-x86_64-pc-windows-msvc.exe'
$ffprobeExe = Join-Path $repoRoot 'app\src-tauri\bin\ffprobe-x86_64-pc-windows-msvc.exe'

foreach ($file in @($appExe, $ffmpegExe, $ffprobeExe)) {
  if (-not (Test-Path -LiteralPath $file -PathType Leaf)) {
    throw "Portable dependency missing: $file"
  }
}

$packageName = 'PulseForge-Portable'
$stage = Join-Path $ArtifactRoot $packageName
if (Test-Path -LiteralPath $ArtifactRoot) {
  Remove-Item -LiteralPath $ArtifactRoot -Recurse -Force
}

foreach ($folder in @($stage, (Join-Path $stage 'bin'), (Join-Path $stage 'data'),
                    (Join-Path $stage 'output'), (Join-Path $stage 'licenses'))) {
  New-Item -ItemType Directory -Path $folder -Force | Out-Null
}

Copy-Item -LiteralPath $appExe -Destination (Join-Path $stage 'PulseForge.exe')
Copy-Item -LiteralPath $ffmpegExe -Destination (Join-Path $stage 'bin\ffmpeg.exe')
Copy-Item -LiteralPath $ffprobeExe -Destination (Join-Path $stage 'bin\ffprobe.exe')
Copy-Item -LiteralPath (Join-Path $repoRoot 'README.md') -Destination (Join-Path $stage 'licenses\UPSTREAM_README.md')

# The per-process environment override instructs WebView2 to keep the browser
# profile in the extracted portable directory, instead of a system profile path.
# Launching PulseForge.exe directly works too, but may use another profile location.
$launcher = @'
@echo off
setlocal
cd /d "%~dp0"
if not exist "data" mkdir "data"
set "WEBVIEW2_USER_DATA_FOLDER=%~dp0data\WebView2"
start "" "%~dp0PulseForge.exe"
'@
Set-Content -LiteralPath (Join-Path $stage 'START_PULSEFORGE.cmd') -Value $launcher -Encoding Ascii

$readme = @'
PULSEFORGE PORTABLE - WINDOWS 11 (x64)
=====================================
NO INSTALLER. NO SETUP. Do not run directly from inside the ZIP.

1. Extract ALL files and folders from the ZIP to a writable location
   (for example, D:\Apps\PulseForge-Portable).
2. Keep PulseForge.exe, bin\, data\, output\, and this file together.
3. Double-click START_PULSEFORGE.cmd. This starts PulseForge.exe with
   WebView2 browser-profile data under data\WebView2.
4. Import audio and try the lyric and spectrum features.
5. Export an MP4 and choose an accessible output location.

THE CONTENTS ARE A REAL MULTI-FILE PORTABLE APP:
- PulseForge.exe              Windows desktop application
- START_PULSEFORGE.cmd        Launcher for local WebView2 user data
- bin\ffmpeg.exe              Required MP4 encoder
- bin\ffprobe.exe             Media inspection/diagnostic tool
- data\                       Writable, portable browser-profile storage
- output\                     Suggested folder for your exported videos
- licenses\                   Upstream author credit and FFmpeg licensing
- BUILD_INFO.txt              Source revision and build environment
- SHA256SUMS.txt              Individual file checksums

Windows 11 normally already includes Microsoft Edge WebView2 Runtime.
If the app cannot start, confirm that WebView2 Runtime is available.
This ZIP does not include a WebView2 installer or an entire fixed runtime.

Use START_PULSEFORGE.cmd for the portable WebView2 profile. If you
launch PulseForge.exe directly, the desktop app might store its profile
outside this directory. Imported media and project files can still refer
to original paths outside the portable folder; moving them can break
those references. This is a no-install portable preview, not a guarantee
that every user file is self-contained.

The software is unsigned; Windows SmartScreen may warn on first use.
Only run a build that you obtained from your own GitHub repository.
'@
Set-Content -LiteralPath (Join-Path $stage 'README_START_HERE.txt') -Value $readme -Encoding UTF8

Set-Content -LiteralPath (Join-Path $stage 'data\README.txt') -Value 'Browser-profile data is stored under data\WebView2 when START_PULSEFORGE.cmd is used. Keep this folder for your settings.' -Encoding UTF8
Set-Content -LiteralPath (Join-Path $stage 'output\README.txt') -Value 'Optional local directory for video exports. Choose this folder when exporting your MP4 from PulseForge.' -Encoding UTF8

$ffmpegVersion = (& (Join-Path $stage 'bin\ffmpeg.exe') -version | Select-Object -First 1)
if ($LASTEXITCODE -ne 0) { throw 'Packaged ffmpeg.exe failed its version check.' }
$ffprobeVersion = (& (Join-Path $stage 'bin\ffprobe.exe') -version | Select-Object -First 1)
if ($LASTEXITCODE -ne 0) { throw 'Packaged ffprobe.exe failed its version check.' }

$notices = @'
PulseForge source: https://github.com/TheAwaken1/PulseForge
Original creator: TheAwaken1. The upstream README states MIT licensing.
Keep upstream copyright and licensing notices with redistributed builds.
This fork adds only Windows packaging and build-related bug fixes.

FFmpeg and FFprobe are third-party multimedia utilities with licensing
that depends on the exact build configuration (LGPL and/or GPL).
Refer to the FFmpeg license information provided below and the official
project licenses: https://ffmpeg.org/legal.html
FFmpeg source: https://ffmpeg.org/download.html
Redistributors must comply with the applicable FFmpeg license, including
source-code availability requirements where relevant.
'@
Set-Content -LiteralPath (Join-Path $stage 'licenses\THIRD_PARTY_NOTICES.txt') -Value $notices -Encoding UTF8
& (Join-Path $stage 'bin\ffmpeg.exe') -L | Out-File -LiteralPath (Join-Path $stage 'licenses\FFMPEG_BINARY_LICENSE_OUTPUT.txt') -Encoding utf8
if ($LASTEXITCODE -ne 0) { throw 'Failed to capture FFmpeg license output.' }

$commit = if ($env:GITHUB_SHA) { $env:GITHUB_SHA } else { 'local' }
$info = @"
PulseForge portable Windows 11 x64 preview
Source: https://github.com/inoriko920-dev/PulseForge
Commit: $commit
Built at UTC: $([DateTime]::UtcNow.ToString('yyyy-MM-dd HH:mm:ss'))
Executable: PulseForge.exe
FFmpeg: $ffmpegVersion
FFprobe: $ffprobeVersion
Format: extracted folder; no installation
"@
Set-Content -LiteralPath (Join-Path $stage 'BUILD_INFO.txt') -Value $info -Encoding UTF8

# SHA hashes are for the files inside the portable folder (exclude the
# checksum manifest itself, so it remains deterministic and verifiable).
$sumLines = @(
  Get-ChildItem -LiteralPath $stage -Recurse -File |
    Sort-Object FullName |
    ForEach-Object {
      $relative = $_.FullName.Substring($stage.Length + 1).Replace('\', '/')
      $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
      "$hash  $relative"
    }
)
Set-Content -LiteralPath (Join-Path $stage 'SHA256SUMS.txt') -Value $sumLines -Encoding Ascii

$zipPath = Join-Path $ArtifactRoot 'PulseForge-Portable-Windows11-x64.zip'
Compress-Archive -LiteralPath $stage -DestinationPath $zipPath -CompressionLevel Optimal -Force

Add-Type -AssemblyName System.IO.Compression
$archive = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
try {
  $names = @($archive.Entries | ForEach-Object { $_.FullName.Replace('\', '/') })
  $required = @(
    'PulseForge-Portable/PulseForge.exe',
    'PulseForge-Portable/START_PULSEFORGE.cmd',
    'PulseForge-Portable/bin/ffmpeg.exe',
    'PulseForge-Portable/bin/ffprobe.exe',
    'PulseForge-Portable/README_START_HERE.txt',
    'PulseForge-Portable/data/README.txt',
    'PulseForge-Portable/output/README.txt',
    'PulseForge-Portable/licenses/THIRD_PARTY_NOTICES.txt',
    'PulseForge-Portable/SHA256SUMS.txt'
  )
  foreach ($item in $required) {
    if ($names -notcontains $item) { throw "Missing required ZIP file: $item" }
  }
  if ($names.Count -lt 10) { throw "Portable ZIP has unexpectedly few entries: $($names.Count)" }
  Write-Host "Portable ZIP PASS: $($names.Count) entries; $((Get-Item $zipPath).Length) bytes."
  Write-Host "Included files:"
  $names | ForEach-Object { Write-Host "  $_" }
}
finally {
  $archive.Dispose()
}

Write-Host "PORTABLE_ZIP=$zipPath"
