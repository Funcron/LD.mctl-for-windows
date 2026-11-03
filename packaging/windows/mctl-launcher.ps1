#Requires -Version 5.1
<#
.SYNOPSIS
  A small window for starting mctl with its options, and for running its other commands.

.DESCRIPTION
  Every option here is a command-line flag of mctl.exe; the box at the bottom shows the exact command that
  Launch will run, so the launcher is also a way to learn the flags. Settings are remembered in
  %APPDATA%\mctl\launcher.json. Start it with Launch-mctl.bat, or:
    powershell -ExecutionPolicy Bypass -File mctl-launcher.ps1 [-ExePath C:\path\to\mctl.exe]
#>
[CmdletBinding()]
param([string]$ExePath)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

# ---- what the options are (from mctl's own CLI; see `mctl --help`) -------------------------------------------
$Themes   = 'Phosphor', 'Retro', 'Retrowave', 'Modern', 'Cosmonaut', 'Teletext', 'Nostromo'
$Vehicles = [ordered]@{
    'iss' = 'ISS'; 'hubble' = 'Hubble'; 'dragon-crew' = 'Crew Dragon'; 'dragon-cargo' = 'Cargo Dragon'
    'jwst' = 'JWST'; 'roman' = 'Roman'; 'tiangong' = 'Tiangong'; 'voyager-1' = 'Voyager 1'
    'voyager-2' = 'Voyager 2'; 'new-horizons' = 'New Horizons'
}
$Sizes = '(default)', '1280x720', '1600x900', '1920x1080', '2560x1440', '640x480'
$ConfigDir = Join-Path $env:APPDATA 'mctl\config'
$SettingsFile = Join-Path $env:APPDATA 'mctl\launcher.json'
$LogFile = Join-Path $env:LOCALAPPDATA 'mctl\cache\mctl.log'

function Find-Mctl {
    $c = @()
    if ($ExePath) { $c += $ExePath }
    $c += (Join-Path $PSScriptRoot 'mctl.exe'),
          (Join-Path $PSScriptRoot '..\..\mctl.exe'),
          (Join-Path $PSScriptRoot '..\..\target\release\mctl.exe'),
          (Join-Path $env:LOCALAPPDATA 'Programs\mctl\mctl.exe')
    foreach ($p in $c) { if ($p -and (Test-Path -LiteralPath $p)) { return (Resolve-Path -LiteralPath $p).Path } }
    $g = Get-Command mctl.exe -ErrorAction SilentlyContinue
    if ($g) { return $g.Source }
    return ''
}

function Quote-Arg([string]$s) {
    if ($s -match '[\s"]') { return '"' + ($s.TrimEnd('\') -replace '"', '\"') + '"' }
    return $s
}

# ---- the form ---------------------------------------------------------------------------------------------
$form = New-Object System.Windows.Forms.Form
$form.Text = 'mctl launcher'
$form.ClientSize = New-Object System.Drawing.Size(640, 690)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedSingle'
$form.MaximizeBox = $false
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

function New-Label($text, $x, $y, $w = 130) {
    $l = New-Object System.Windows.Forms.Label
    $l.Text = $text; $l.Left = $x; $l.Top = $y + 3; $l.Width = $w; $l.Height = 20
    return $l
}
function New-Combo($items, $x, $y, $w = 200, [switch]$Editable) {
    $c = New-Object System.Windows.Forms.ComboBox
    $c.Left = $x; $c.Top = $y; $c.Width = $w
    $c.DropDownStyle = if ($Editable) { 'DropDown' } else { 'DropDownList' }
    foreach ($i in $items) { [void]$c.Items.Add($i) }
    $c.SelectedIndex = 0
    return $c
}
function New-Check($text, $x, $y, $w = 280) {
    $c = New-Object System.Windows.Forms.CheckBox
    $c.Text = $text; $c.Left = $x; $c.Top = $y; $c.Width = $w; $c.Height = 22
    return $c
}
function New-Text($x, $y, $w = 200, $text = '') {
    $t = New-Object System.Windows.Forms.TextBox
    $t.Left = $x; $t.Top = $y; $t.Width = $w; $t.Text = $text
    return $t
}
function New-Button($text, $x, $y, $w = 280, $h = 30) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Left = $x; $b.Top = $y; $b.Width = $w; $b.Height = $h
    return $b
}

# mctl.exe location
$form.Controls.Add((New-Label 'mctl.exe' 12 12 60))
$txtExe = New-Text 75 12 450 (Find-Mctl)
$form.Controls.Add($txtExe)
$btnBrowse = New-Button 'Browse...' 535 10 92 26
$form.Controls.Add($btnBrowse)

$tabs = New-Object System.Windows.Forms.TabControl
$tabs.Left = 10; $tabs.Top = 46; $tabs.Width = 620; $tabs.Height = 440
$form.Controls.Add($tabs)
$tabConsole = New-Object System.Windows.Forms.TabPage; $tabConsole.Text = 'Console'
$tabKiosk   = New-Object System.Windows.Forms.TabPage; $tabKiosk.Text   = 'Kiosk / CRT'
$tabTools   = New-Object System.Windows.Forms.TabPage; $tabTools.Text   = 'Tools'
$tabs.TabPages.AddRange(@($tabConsole, $tabKiosk, $tabTools))

# -- Console tab
$cmbTheme = New-Combo (@('(default)') + $Themes) 150 14
$cmbVehicle = New-Combo (@('(default)') + @($Vehicles.Keys | ForEach-Object { $_ })) 150 46
$cmbSize = New-Combo $Sizes 150 78 200 -Editable
$cmbPresent = New-Combo @('fifo', 'immediate', 'mailbox') 150 110
$txtFps = New-Text 150 142 80
$txtReplay = New-Text 150 174 200
$chkFull = New-Check 'Fullscreen' 20 212
$chkOffline = New-Check 'Offline (cached data only, no network)' 20 238 380
$chkNoRec = New-Check 'Do not record this run' 20 264
$chkLow = New-Check 'Prefer the low-power (integrated) GPU' 20 290 380
$chkSoft = New-Check 'Allow a software (CPU) renderer' 20 316 380
$hint = New-Object System.Windows.Forms.Label
$hint.Left = 360; $hint.Top = 76; $hint.Width = 240; $hint.Height = 100
$hint.Text = "Size is WxH, e.g. 1920x1080.`r`nMax FPS caps the frame rate (blank = none).`r`nReplay: start, an ISO time such as 2026-10-23T00:00:00, or an offset like -2h."
$hint.ForeColor = [System.Drawing.Color]::DimGray
$tabConsole.Controls.AddRange(@(
    (New-Label 'Theme' 20 14), $cmbTheme,
    (New-Label 'Vehicle' 20 46), $cmbVehicle,
    (New-Label 'Window size' 20 78), $cmbSize,
    (New-Label 'Present mode' 20 110), $cmbPresent,
    (New-Label 'Max FPS' 20 142), $txtFps,
    (New-Label 'Replay from' 20 174), $txtReplay,
    $chkFull, $chkOffline, $chkNoRec, $chkLow, $chkSoft, $hint))

# -- Kiosk tab
$chkKiosk = New-Check 'Run in kiosk mode (the unattended Raspberry Pi / CRT display)' 20 14 560
$cmbStyle = New-Combo @('mixed', 'pretty', 'dense') 150 46
$cmbOrder = New-Combo @('sequential', 'random', 'vehicle') 150 78
$txtDwell = New-Text 150 110 80
$chkCycle = New-Check 'A different random theme with every scene' 20 142 380
$chkWindowed = New-Check 'Stay in a window instead of taking the whole screen' 20 168 420
$lstKiosk = New-Object System.Windows.Forms.CheckedListBox
$lstKiosk.Left = 150; $lstKiosk.Top = 224; $lstKiosk.Width = 220; $lstKiosk.Height = 160; $lstKiosk.CheckOnClick = $true
foreach ($k in $Vehicles.Keys) { [void]$lstKiosk.Items.Add($k) }
$kioskHint = New-Object System.Windows.Forms.Label
$kioskHint.Left = 385; $kioskHint.Top = 46; $kioskHint.Width = 215; $kioskHint.Height = 150
$kioskHint.Text = "mixed: pictures and console pages`r`npretty: pictures only`r`ndense: console pages only`r`n`r`nsequential / random / vehicle: the order of the scenes.`r`n`r`nDwell is seconds per vehicle. The window size, offline and GPU options on the Console tab apply here too."
$kioskHint.ForeColor = [System.Drawing.Color]::DimGray
$tabKiosk.Controls.AddRange(@(
    $chkKiosk,
    (New-Label 'Scenes' 20 46), $cmbStyle,
    (New-Label 'Order' 20 78), $cmbOrder,
    (New-Label 'Dwell (seconds)' 20 110), $txtDwell,
    $chkCycle, $chkWindowed,
    (New-Label 'Only these vehicles' 20 200 130), (New-Label '(none ticked = all)' 20 222 130), $lstKiosk, $kioskHint))

# -- Tools tab
$btnCheck = New-Button 'Check the configuration and data sources' 20 20 330
$btnAbout = New-Button 'About: licence, credits and third-party notices' 20 58 330
$btnExport = New-Button 'Export every recorded table as CSV...' 20 96 330
$btnShot = New-Button 'Save screenshots of every page...' 20 134 330
$btnCfg = New-Button 'Open the config folder' 20 190 160
$btnLog = New-Button 'Open the log' 190 190 160
$btnLnk = New-Button 'Create a desktop shortcut with these options' 20 246 330
$toolsHint = New-Object System.Windows.Forms.Label
$toolsHint.Left = 365; $toolsHint.Top = 20; $toolsHint.Width = 235; $toolsHint.Height = 300
$toolsHint.Text = "Check, About, Export and Screenshots run in a console window that stays open so you can read the result.`r`n`r`nScreenshots uses the theme on the Console tab (all themes if it is (default)) and renders on your GPU; it can take a minute.`r`n`r`nThe user config is empty until you create it: copy the settings you want from default-config.toml into config.toml in the config folder."
$toolsHint.ForeColor = [System.Drawing.Color]::DimGray
$tabTools.Controls.AddRange(@($btnCheck, $btnAbout, $btnExport, $btnShot, $btnCfg, $btnLog, $btnLnk, $toolsHint))

# -- the command preview and Launch
$form.Controls.Add((New-Label 'Command' 12 496 70))
$txtPreview = New-Text 12 518 616 ''
$txtPreview.Multiline = $true; $txtPreview.ReadOnly = $true; $txtPreview.Height = 78
$txtPreview.ScrollBars = 'Vertical'; $txtPreview.Font = New-Object System.Drawing.Font('Consolas', 9)
$form.Controls.Add($txtPreview)
$btnCopy = New-Button 'Copy command' 12 610 150 36
$btnLaunch = New-Button 'Launch' 380 610 248 36
$btnLaunch.Font = New-Object System.Drawing.Font('Segoe UI', 11, [System.Drawing.FontStyle]::Bold)
$form.Controls.AddRange(@($btnCopy, $btnLaunch))
$status = New-Object System.Windows.Forms.Label
$status.Left = 12; $status.Top = 656; $status.Width = 616; $status.Height = 24
$status.ForeColor = [System.Drawing.Color]::DimGray
$form.Controls.Add($status)

# ---- turning the controls into mctl's arguments -----------------------------------------------------------
function Get-GlobalArgs {
    $a = New-Object System.Collections.Generic.List[string]
    if ($chkOffline.Checked) { $a.Add('--offline') }
    if ($chkNoRec.Checked) { $a.Add('--no-record') }
    if ($chkLow.Checked) { $a.Add('--low-power') }
    if ($chkSoft.Checked) { $a.Add('--allow-software') }
    if ($cmbVehicle.Text -and $cmbVehicle.Text -ne '(default)') { $a.Add('--vehicle'); $a.Add($cmbVehicle.Text) }
    if ($txtFps.Text.Trim()) { $a.Add('--max-fps'); $a.Add($txtFps.Text.Trim()) }
    if ($txtReplay.Text.Trim()) { $a.Add('--replay'); $a.Add($txtReplay.Text.Trim()) }
    if ($chkKiosk.Checked) {
        $a.Add('--kiosk')
        $a.Add('--kiosk-style'); $a.Add($cmbStyle.Text)
        $a.Add('--kiosk-order'); $a.Add($cmbOrder.Text)
        if ($chkCycle.Checked) { $a.Add('--kiosk-theme-cycle') }
        if ($txtDwell.Text.Trim()) { $a.Add('--dwell'); $a.Add($txtDwell.Text.Trim()) }
        $ids = @($lstKiosk.CheckedItems | ForEach-Object { [string]$_ })
        if ($ids.Count -gt 0) { $a.Add('--kiosk-vehicles'); $a.Add($ids -join ',') }
    }
    return , $a.ToArray()
}

# The window options belong to the console itself, so they go after the global ones.
function Get-LaunchArgs {
    $a = New-Object System.Collections.Generic.List[string]
    $a.AddRange([string[]](Get-GlobalArgs))
    if ($cmbTheme.Text -and $cmbTheme.Text -ne '(default)') { $a.Add('--theme'); $a.Add($cmbTheme.Text) }
    $size = $cmbSize.Text.Trim()
    if ($size -and $size -ne '(default)') { $a.Add('--size'); $a.Add($size) }
    if ($chkFull.Checked) { $a.Add('--fullscreen') }
    if ($chkKiosk.Checked -and $chkWindowed.Checked) { $a.Add('--windowed') }
    if ($cmbPresent.Text -ne 'fifo') { $a.Add('--present'); $a.Add($cmbPresent.Text) }
    return , $a.ToArray()
}

function Join-Args([string[]]$a) { return (($a | ForEach-Object { Quote-Arg $_ }) -join ' ') }

function Update-Preview {
    $exe = $txtExe.Text.Trim()
    if (-not $exe) { $exe = 'mctl.exe' }
    $args1 = Join-Args (Get-LaunchArgs)
    $txtPreview.Text = ((Quote-Arg $exe) + ' ' + $args1).TrimEnd()
}

# ---- actions ----------------------------------------------------------------------------------------------
# Processes launched in the last few seconds: if one dies straight away (no GPU, bad option) say why,
# instead of failing silently. One shared timer, so nothing depends on closures.
$script:watch = New-Object System.Collections.ArrayList
$watchTimer = New-Object System.Windows.Forms.Timer
$watchTimer.Interval = 1000

function Get-Exe {
    $exe = $txtExe.Text.Trim().Trim('"')
    if (-not $exe -or -not (Test-Path -LiteralPath $exe)) {
        [void][System.Windows.Forms.MessageBox]::Show('Cannot find mctl.exe. Use Browse... to point at it.', 'mctl launcher', 'OK', 'Warning')
        return $null
    }
    return $exe
}

function Get-LogTail {
    if (Test-Path -LiteralPath $LogFile) { return ((Get-Content -LiteralPath $LogFile -Tail 12) -join "`r`n") }
    return '(no log found)'
}

function Start-Console {
    $exe = Get-Exe; if (-not $exe) { return }
    Save-Settings
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exe
    $psi.Arguments = Join-Args (Get-LaunchArgs)
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.WorkingDirectory = Split-Path -Parent $exe
    try { $p = [System.Diagnostics.Process]::Start($psi) }
    catch { [void][System.Windows.Forms.MessageBox]::Show("Could not start mctl:`r`n$($_.Exception.Message)", 'mctl launcher', 'OK', 'Error'); return }
    $status.Text = "Started mctl (process $($p.Id))."
    [void]$script:watch.Add($p)
    $watchTimer.Start()
}

# Run a subcommand in a console window that stays open.
function Start-Visible([string[]]$sub) {
    $exe = Get-Exe; if (-not $exe) { return }
    Save-Settings
    $line = (Quote-Arg $exe) + ' ' + (Join-Args (Get-GlobalArgs)) + ' ' + (Join-Args $sub)
    Start-Process -FilePath 'cmd.exe' -ArgumentList ('/k "' + $line.Trim() + '"') -WorkingDirectory (Split-Path -Parent $exe)
    $status.Text = 'Opened a console window.'
}

function Select-Folder([string]$description) {
    $d = New-Object System.Windows.Forms.FolderBrowserDialog
    $d.Description = $description
    if ($d.ShowDialog() -eq 'OK') { return $d.SelectedPath }
    return $null
}

# ---- settings ---------------------------------------------------------------------------------------------
$Fields = [ordered]@{
    theme = $cmbTheme; vehicle = $cmbVehicle; size = $cmbSize; present = $cmbPresent; fps = $txtFps; replay = $txtReplay
    fullscreen = $chkFull; offline = $chkOffline; norecord = $chkNoRec; lowpower = $chkLow; software = $chkSoft
    kiosk = $chkKiosk; style = $cmbStyle; order = $cmbOrder; dwell = $txtDwell; cycle = $chkCycle; windowed = $chkWindowed
}

function Save-Settings {
    try {
        $o = [ordered]@{ exe = $txtExe.Text }
        foreach ($k in $Fields.Keys) {
            $c = $Fields[$k]
            $o[$k] = if ($c -is [System.Windows.Forms.CheckBox]) { $c.Checked } else { $c.Text }
        }
        $o['kioskVehicles'] = @($lstKiosk.CheckedItems | ForEach-Object { [string]$_ })
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $SettingsFile) | Out-Null
        $o | ConvertTo-Json | Set-Content -LiteralPath $SettingsFile -Encoding UTF8
    } catch { }   # remembering settings is a convenience; never block a launch on it
}

function Load-Settings {
    try {
        if (-not (Test-Path -LiteralPath $SettingsFile)) { return }
        $o = Get-Content -LiteralPath $SettingsFile -Raw | ConvertFrom-Json
        if ($o.exe -and -not $txtExe.Text.Trim() -and (Test-Path -LiteralPath $o.exe)) { $txtExe.Text = $o.exe }
        foreach ($k in $Fields.Keys) {
            $v = $o.$k
            if ($null -eq $v) { continue }
            $c = $Fields[$k]
            if ($c -is [System.Windows.Forms.CheckBox]) { $c.Checked = [bool]$v } else { $c.Text = [string]$v }
        }
        $want = @($o.kioskVehicles)
        for ($i = 0; $i -lt $lstKiosk.Items.Count; $i++) { $lstKiosk.SetItemChecked($i, ($want -contains [string]$lstKiosk.Items[$i])) }
    } catch { }
}

# ---- wiring -----------------------------------------------------------------------------------------------
$txtDwell.Text = '20'
Load-Settings

$changed = { Update-Preview }
foreach ($c in (@($Fields.Values) + @($txtExe))) {
    if ($c -is [System.Windows.Forms.CheckBox]) { $c.Add_CheckedChanged($changed) }
    elseif ($c -is [System.Windows.Forms.ComboBox]) { $c.Add_TextChanged($changed); $c.Add_SelectedIndexChanged($changed) }
    else { $c.Add_TextChanged($changed) }
}
$lstKiosk.Add_ItemCheck({ $form.BeginInvoke([Action]{ Update-Preview }) | Out-Null })

$btnBrowse.Add_Click({
    $d = New-Object System.Windows.Forms.OpenFileDialog
    $d.Filter = 'mctl.exe|mctl.exe|Programs|*.exe'
    if ($d.ShowDialog() -eq 'OK') { $txtExe.Text = $d.FileName }
})
$btnLaunch.Add_Click({ Start-Console })
$btnCopy.Add_Click({ [System.Windows.Forms.Clipboard]::SetText($txtPreview.Text); $status.Text = 'Command copied.' })
$btnCheck.Add_Click({ Start-Visible @('check') })
$btnAbout.Add_Click({ Start-Visible @('about') })
$btnExport.Add_Click({
    $dir = Select-Folder 'Export every recorded table as CSV into this folder'
    if ($dir) { Start-Visible @('export', '--out', $dir) }
})
$btnShot.Add_Click({
    $dir = Select-Folder 'Save one PNG per page into this folder'
    if (-not $dir) { return }
    $sub = @('shot', '--out-dir', $dir, '--pages', 'all')
    if ($cmbTheme.Text -and $cmbTheme.Text -ne '(default)') { $sub += @('--theme', $cmbTheme.Text) }
    Start-Visible $sub
})
$btnCfg.Add_Click({
    New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null
    Start-Process explorer.exe -ArgumentList ('"' + $ConfigDir + '"')
})
$btnLog.Add_Click({
    if (Test-Path -LiteralPath $LogFile) { Start-Process notepad.exe -ArgumentList ('"' + $LogFile + '"') }
    else { [void][System.Windows.Forms.MessageBox]::Show("No log yet ($LogFile). It appears after mctl has run once.", 'mctl launcher') }
})
$btnLnk.Add_Click({
    $exe = Get-Exe; if (-not $exe) { return }
    $dlg = New-Object System.Windows.Forms.SaveFileDialog
    $dlg.Filter = 'Shortcut|*.lnk'
    $dlg.FileName = 'mctl.lnk'
    $dlg.InitialDirectory = [Environment]::GetFolderPath('Desktop')
    if ($dlg.ShowDialog() -ne 'OK') { return }
    $s = (New-Object -ComObject WScript.Shell).CreateShortcut($dlg.FileName)
    $s.TargetPath = $exe
    $s.Arguments = Join-Args (Get-LaunchArgs)
    $s.WorkingDirectory = Split-Path -Parent $exe
    $s.Description = 'mctl with the options chosen in the launcher'
    $s.Save()
    $status.Text = "Saved $($dlg.FileName)."
})
$watchTimer.Add_Tick({
    foreach ($p in @($script:watch)) {
        if ($p.HasExited) {
            [void]$script:watch.Remove($p)
            if ($p.ExitCode -ne 0 -and ((Get-Date) - $p.StartTime).TotalSeconds -lt 15) {
                $status.Text = "mctl exited with code $($p.ExitCode)."
                [void][System.Windows.Forms.MessageBox]::Show("mctl stopped straight away (exit code $($p.ExitCode)). Last lines of the log:`r`n`r`n$(Get-LogTail)", 'mctl launcher', 'OK', 'Warning')
            }
        } elseif (((Get-Date) - $p.StartTime).TotalSeconds -gt 15) {
            [void]$script:watch.Remove($p)   # it has been running a while: it started fine
        }
    }
    if ($script:watch.Count -eq 0) { $watchTimer.Stop() }
})
$form.Add_FormClosing({ Save-Settings })

Update-Preview
if (-not $txtExe.Text.Trim()) { $status.Text = 'mctl.exe not found next to the launcher: use Browse... to point at it.' }
[void]$form.ShowDialog()
