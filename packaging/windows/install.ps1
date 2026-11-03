<#
.SYNOPSIS
  Install mctl on Windows: from a release zip, or by building from a source checkout.

.DESCRIPTION
  Run from an unpacked release (it finds mctl.exe beside this script's parent folder) or from a git checkout
  (it builds with cargo first). Installs mctl.exe into %LOCALAPPDATA%\Programs\mctl and adds a Start Menu
  shortcut. Nothing needs administrator rights.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File packaging\windows\install.ps1
  powershell -ExecutionPolicy Bypass -File packaging\windows\install.ps1 -AddToPath
  powershell -ExecutionPolicy Bypass -File packaging\windows\install.ps1 -Uninstall
#>
[CmdletBinding()]
param(
    [string]$Prefix = (Join-Path $env:LOCALAPPDATA 'Programs\mctl'),
    [switch]$AddToPath,
    [switch]$NoShortcut,
    [switch]$Uninstall
)
$ErrorActionPreference = 'Stop'

$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$repo = Split-Path -Parent (Split-Path -Parent $here)
$exe = Join-Path $Prefix 'mctl.exe'
$startMenu = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs'
$shortcut = Join-Path $startMenu 'mctl.lnk'
$launcherShortcut = Join-Path $startMenu 'mctl launcher.lnk'

function Remove-FromUserPath([string]$dir) {
    $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not $cur) { return }
    $keep = ($cur -split ';') | Where-Object { $_ -and ($_.TrimEnd('\') -ne $dir.TrimEnd('\')) }
    [Environment]::SetEnvironmentVariable('Path', ($keep -join ';'), 'User')
}

if ($Uninstall) {
    Remove-Item -Force -ErrorAction SilentlyContinue $exe, $shortcut, $launcherShortcut, (Join-Path $Prefix 'mctl-launcher.ps1'), (Join-Path $Prefix 'Launch-mctl.bat')
    Remove-Item -Force -ErrorAction SilentlyContinue (Join-Path $Prefix '*.md'), (Join-Path $Prefix 'LICENSE')
    if ((Test-Path $Prefix) -and -not (Get-ChildItem $Prefix)) { Remove-Item $Prefix }
    Remove-FromUserPath $Prefix
    Write-Host "removed mctl from $Prefix (your config, cache and recordings under %APPDATA%\mctl and %LOCALAPPDATA%\mctl are untouched)"
    exit 0
}

# 1. Find or build the binary.
$built = $null
if (Test-Path (Join-Path $repo 'Cargo.toml')) {
    if (-not (Get-Command cargo -ErrorAction SilentlyContinue)) {
        throw "cargo not found. Install Rust from https://rustup.rs (it will also tell you to install the 'Visual Studio Build Tools' with the 'Desktop development with C++' workload, which Rust needs to link on Windows), then run this again."
    }
    Write-Host 'building mctl (release); the first build takes a few minutes...'
    Push-Location $repo
    try {
        cargo build --release --locked -p mctl
        if ($LASTEXITCODE -ne 0) { throw 'cargo build failed' }
    } finally { Pop-Location }
    $built = Join-Path $repo 'target\release\mctl.exe'
} elseif (Test-Path (Join-Path $repo 'mctl.exe')) {
    $built = Join-Path $repo 'mctl.exe'
}
if (-not $built -or -not (Test-Path $built)) { throw 'no mctl.exe found: run this from an unpacked release or from a source checkout' }

# 2. Install it.
New-Item -ItemType Directory -Force -Path $Prefix | Out-Null
Copy-Item -Force $built $exe
foreach ($f in 'README.md', 'LICENSE', 'THIRD-PARTY-NOTICES.md', 'CHANGELOG.md') {
    $src = Join-Path $repo $f
    if (Test-Path $src) { Copy-Item -Force $src $Prefix }
}

# The launcher: a window for choosing the theme, vehicle, kiosk mode and the other options.
foreach ($f in 'mctl-launcher.ps1', 'Launch-mctl.bat') {
    $src = Join-Path $here $f
    if (-not (Test-Path $src)) { $src = Join-Path $repo $f }
    if (Test-Path $src) { Copy-Item -Force $src $Prefix }
}

if (-not $NoShortcut) {
    $sh = (New-Object -ComObject WScript.Shell).CreateShortcut($shortcut)
    $sh.TargetPath = $exe
    $sh.WorkingDirectory = $Prefix
    $sh.Description = 'mctl: mission-control display for the ISS and the spacecraft around it'
    $sh.Save()
    if (Test-Path (Join-Path $Prefix 'mctl-launcher.ps1')) {
        $l = (New-Object -ComObject WScript.Shell).CreateShortcut($launcherShortcut)
        $l.TargetPath = (Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe')
        $l.Arguments = '-NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "' + (Join-Path $Prefix 'mctl-launcher.ps1') + '"'
        $l.WorkingDirectory = $Prefix
        $l.Description = 'Choose the theme, vehicle and other options, then start mctl'
        $l.Save()
    }
}

if ($AddToPath) {
    $cur = [Environment]::GetEnvironmentVariable('Path', 'User')
    if (-not (($cur -split ';') -contains $Prefix)) {
        [Environment]::SetEnvironmentVariable('Path', (($cur, $Prefix | Where-Object { $_ }) -join ';'), 'User')
        Write-Host 'added to your PATH; open a new terminal to use `mctl` from anywhere'
    }
}

Write-Host "installed $exe"
& $exe --version
