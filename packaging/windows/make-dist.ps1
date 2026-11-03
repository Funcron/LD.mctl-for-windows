<#
.SYNOPSIS
  Assemble the Windows release zip and its checksum (the counterpart of packaging/make-dist.sh).

.EXAMPLE
  cargo build --profile dist --locked -p mctl
  powershell -File packaging\windows\make-dist.ps1 -Target x86_64-pc-windows-msvc
  # -> dist\mctl-<version>-x86_64-pc-windows-msvc.zip and .zip.sha256
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Target,
    [string]$Binary = 'target\dist\mctl.exe'
)
$ErrorActionPreference = 'Stop'
Set-Location (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

if (-not (Test-Path $Binary)) { throw "$Binary not found (build it first with: cargo build --profile dist --locked -p mctl)" }
$version = (Select-String -Path Cargo.toml -Pattern '^version\s*=\s*"([^"]+)"' | Select-Object -First 1).Matches[0].Groups[1].Value
if (-not $version) { throw 'cannot read the version from Cargo.toml' }

$name = "mctl-$version-$Target"
$stage = Join-Path 'dist' $name
$zip = Join-Path 'dist' "$name.zip"
Remove-Item -Recurse -Force -ErrorAction SilentlyContinue $stage, $zip, "$zip.sha256"
New-Item -ItemType Directory -Force -Path (Join-Path $stage 'packaging\windows') | Out-Null

Copy-Item $Binary (Join-Path $stage 'mctl.exe')
Copy-Item README.md, LICENSE, THIRD-PARTY-NOTICES.md, CHANGELOG.md $stage
Copy-Item config\default.toml (Join-Path $stage 'default-config.toml')
Copy-Item packaging\windows\install.ps1 (Join-Path $stage 'packaging\windows')

Compress-Archive -Path $stage -DestinationPath $zip
Remove-Item -Recurse -Force $stage

# Same "<hash>  <file>" layout as sha256sum, so one verification step covers every platform.
$hash = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLower()
[System.IO.File]::WriteAllText("$zip.sha256", "$hash  $name.zip`n", (New-Object System.Text.UTF8Encoding $false))
Write-Host $zip
