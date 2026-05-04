#Requires -Version 7
<#
.SYNOPSIS
    PowerShell Profile Installer v0.0.1
.DESCRIPTION
    Interactive installer with prerequisite checking and dependency resolution.
    Detects installed tools, resolves dependencies, lets you pick components.
.EXAMPLE
    .\Install-Profile.ps1              # interactive menu
    .\Install-Profile.ps1 --all        # install all defaults, no prompts
    .\Install-Profile.ps1 --check      # only run system check, don't install
.LINK
    https://github.com/LinhDangDev/Config-Oh-My-Posh
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$VERSION    = "0.0.1"
$SCRIPT_DIR = $PSScriptRoot

# ─── Helpers ──────────────────────────────────────────────────────────────────

function Write-Header([string]$subtitle = '') {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   PowerShell Profile Installer  v$VERSION          ║" -ForegroundColor Cyan
    Write-Host "  ║   github.com/LinhDangDev/Config-Oh-My-Posh     ║" -ForegroundColor DarkGray
    Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    if ($subtitle) { Write-Host "  $subtitle" -ForegroundColor Yellow }
    Write-Host ""
}

function Write-OK   ([string]$m) { Write-Host "  ✓  $m" -ForegroundColor Green }
function Write-Warn ([string]$m) { Write-Host "  ⚠  $m" -ForegroundColor Yellow }
function Write-Fail ([string]$m) { Write-Host "  ✗  $m" -ForegroundColor Red }
function Write-Info ([string]$m) { Write-Host "  →  $m" -ForegroundColor Cyan }
function Write-Skip ([string]$m) { Write-Host "  ○  $m" -ForegroundColor DarkGray }
function Write-Sep               { Write-Host "  $(('─' * 54))" -ForegroundColor DarkGray }

function Test-Cmd ([string]$name) { [bool](Get-Command $name -ErrorAction SilentlyContinue) }
function Confirm  ([string]$p)    { $r = Read-Host "  $p [Y/n]"; return ($r -eq '' -or $r -match '^[Yy]') }

# ─── Phase 1: System Requirements Check ───────────────────────────────────────
#
#  Each entry: Name, Check scriptblock, Required bool,
#              UsedBy string[], Deps string[], Alt string (alternative)

$sysReqs = [ordered]@{

    'PowerShell 7+' = @{
        Check    = { $PSVersionTable.PSVersion.Major -ge 7 }
        Required = $true
        UsedBy   = @('Core Profile', 'PSReadLine')
        Fix      = 'winget install Microsoft.PowerShell'
    }

    'winget' = @{
        Check    = { Test-Cmd 'winget' }
        Required = $false
        UsedBy   = @('Oh My Posh', 'Zoxide', 'lazydocker', 'git (if missing)')
        Alt      = 'scoop'
        Fix      = 'https://aka.ms/getwinget'
    }

    'scoop' = @{
        Check    = { Test-Cmd 'scoop' }
        Required = $false
        UsedBy   = @('Alternative package manager')
        Alt      = 'winget'
        Fix      = "irm get.scoop.sh | iex"
    }

    'git' = @{
        Check    = { Test-Cmd 'git' }
        Required = $false
        UsedBy   = @('Core Profile git shortcuts (gs glog gco gcp...)', 'gh completions')
        Fix      = 'winget install Git.Git   OR   scoop install git'
    }

    'node / npm' = @{
        Check    = { Test-Cmd 'node' }
        Required = $false
        UsedBy   = @('Yarn/npm shortcuts (yd yt yb yi nvv...)')
        Fix      = 'winget install OpenJS.NodeJS   OR   scoop install nodejs'
    }

    'yarn' = @{
        Check    = { Test-Cmd 'yarn' }
        Required = $false
        UsedBy   = @('Yarn shortcuts (yd yda ydw yt ytw yb yi)','Drizzle helpers (db-push db-gen db-studio)')
        Alt      = 'npm (npm run ... still works)'
        Fix      = 'npm install -g yarn   OR   corepack enable'
    }

    'docker' = @{
        Check    = { Test-Cmd 'docker' }
        Required = $false
        UsedBy   = @('Docker helpers (dps dex dmon dl-split)','lazydocker')
        Fix      = 'winget install Docker.DockerDesktop'
    }

    'gh (GitHub CLI)' = @{
        Check    = { Test-Cmd 'gh' }
        Required = $false
        UsedBy   = @('gh Tab completions (gh pr gh repo gh issue...)')
        Deps     = @('git')   # gh needs git
        Fix      = 'winget install GitHub.cli   OR   scoop install gh'
    }

    'oh-my-posh' = @{
        Check    = { Test-Cmd 'oh-my-posh' }
        Required = $false
        UsedBy   = @('Prompt theme','Nerd Font installer')
        Fix      = 'winget install JanDeDobbeleer.OhMyPosh -s winget'
    }
}

# Run all checks and store results
$checkResults = @{}
foreach ($name in $sysReqs.Keys) {
    try { $checkResults[$name] = & $sysReqs[$name].Check }
    catch { $checkResults[$name] = $false }
}

function Show-SystemCheck {
    Write-Header "Phase 1 — System Requirements"

    $hasPackageManager = $checkResults['winget'] -or $checkResults['scoop']

    foreach ($name in $sysReqs.Keys) {
        $req    = $sysReqs[$name]
        $ok     = $checkResults[$name]
        $label  = $name.PadRight(20)

        if ($ok) {
            Write-Host "  ✓  $label" -NoNewline -ForegroundColor Green
            Write-Host " installed" -ForegroundColor DarkGray
        } else {
            $isRequired = $req.Required
            $hasAlt     = $req.ContainsKey('Alt') -and (
                            ($name -eq 'winget' -and $checkResults['scoop']) -or
                            ($name -eq 'scoop'  -and $checkResults['winget']) -or
                            ($name -eq 'yarn'   -and $checkResults['node / npm'])
                          )

            if ($isRequired) {
                Write-Host "  ✗  $label" -NoNewline -ForegroundColor Red
                Write-Host " MISSING (required)" -ForegroundColor Red
                Write-Host "     Fix: $($req.Fix)" -ForegroundColor DarkGray
            } elseif ($hasAlt) {
                Write-Host "  ○  $label" -NoNewline -ForegroundColor DarkGray
                Write-Host " not found — alternative available ($($req.Alt))" -ForegroundColor DarkGray
            } else {
                Write-Host "  ⚠  $label" -NoNewline -ForegroundColor Yellow
                Write-Host " not installed — some features disabled" -ForegroundColor DarkGray
                Write-Host "     Fix: $($req.Fix)" -ForegroundColor DarkGray

                # Show which features depend on this
                if ($req.ContainsKey('UsedBy') -and $req.UsedBy.Count -gt 0) {
                    Write-Host "     Needed for: $($req.UsedBy -join ', ')" -ForegroundColor DarkGray
                }

                # Check if this item has unmet deps itself
                if ($req.ContainsKey('Deps')) {
                    $unmetDeps = $req.Deps | Where-Object { -not $checkResults[$_] }
                    if ($unmetDeps) {
                        Write-Host "     Missing deps: $($unmetDeps -join ', ')" -ForegroundColor Red
                    }
                }
            }
        }
    }

    Write-Host ""
    Write-Sep

    # Summary
    $missing  = $sysReqs.Keys | Where-Object { -not $checkResults[$_] -and $sysReqs[$_].Required }
    $warnings = $sysReqs.Keys | Where-Object {
        -not $checkResults[$_] -and -not $sysReqs[$_].Required -and
        -not ($sysReqs[$_].ContainsKey('Alt') -and (
            ($_ -eq 'winget' -and $checkResults['scoop']) -or
            ($_ -eq 'scoop'  -and $checkResults['winget']) -or
            ($_ -eq 'yarn'   -and $checkResults['node / npm'])
        ))
    }

    if ($missing) {
        Write-Host ""
        Write-Fail "Required prerequisites missing — cannot continue:"
        $missing | ForEach-Object { Write-Host "    • $_ : $($sysReqs[$_].Fix)" -ForegroundColor Red }
        Write-Host ""
        return $false
    }

    if (-not $hasPackageManager) {
        Write-Host ""
        Write-Warn "No package manager found (winget or scoop)."
        Write-Host "  Some components cannot be auto-installed." -ForegroundColor DarkGray
        Write-Host "  Install winget: https://aka.ms/getwinget" -ForegroundColor DarkGray
        Write-Host ""
    }

    if ($warnings) {
        Write-Host ""
        Write-Warn "$($warnings.Count) optional tool(s) not found — related shortcuts will exist"
        Write-Host "  but won't work until those tools are installed." -ForegroundColor DarkGray
    }

    Write-Host ""
    return $true
}

# ─── Phase 2: Component Definitions ───────────────────────────────────────────

$components = [ordered]@{

    'profile' = @{
        Label       = "Core Profile  (shortcuts, autocomplete, UTF-8, auto-ls)"
        Required    = $true
        Selected    = $true
        Deps        = @()               # no hard deps — soft deps shown in check
        SoftDeps    = @('git','node / npm','yarn','docker')
        Check       = { Test-Path $PROFILE }
        Install     = {
            $dest = $PROFILE
            $dir  = Split-Path $dest
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item "$SCRIPT_DIR\Microsoft.powershell_profile.ps1" $dest -Force
        }
    }

    'ohmyposh' = @{
        Label       = "Oh My Posh    (prompt theme)"
        Required    = $false
        Selected    = $true
        Deps        = @()
        SoftDeps    = @('winget')
        Check       = { Test-Cmd 'oh-my-posh' }
        Install     = {
            if (Test-Cmd 'winget') {
                winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements | Out-Null
            } elseif (Test-Cmd 'scoop') {
                scoop install oh-my-posh
            } else { throw "No package manager available (winget or scoop)" }

            $src  = "$SCRIPT_DIR\themes\iterm2.omp.json"
            $dest = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\"
            if (Test-Path $src) {
                New-Item -ItemType Directory -Path $dest -Force | Out-Null
                Copy-Item $src $dest -Force
            }
        }
    }

    'nerd-font' = @{
        Label       = "Nerd Font     (CaskaydiaCove — icons for prompt + ls)"
        Required    = $false
        Selected    = $true
        Deps        = @('oh-my-posh')   # needs omp to run `oh-my-posh font install`
        SoftDeps    = @()
        Check       = {
            (Get-ItemProperty 'HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts' -ErrorAction SilentlyContinue).PSObject.Properties.Name |
                Where-Object { $_ -match 'Cascadia|CaskaydiaCove|Nerd' } | Select-Object -First 1
        }
        Install     = { oh-my-posh font install CascadiaCode }
    }

    'terminal-icons' = @{
        Label       = "Terminal-Icons (file icons in ls output)"
        Required    = $false
        Selected    = $true
        Deps        = @()
        SoftDeps    = @()
        Check       = { Get-Module -ListAvailable -Name Terminal-Icons }
        Install     = { Install-Module -Name Terminal-Icons -Scope CurrentUser -Force }
    }

    'psreadline' = @{
        Label       = "PSReadLine    (ghost text, InlineView, syntax colors)"
        Required    = $false
        Selected    = $true
        Deps        = @()
        SoftDeps    = @()
        Check       = {
            $m = Get-Module -ListAvailable -Name PSReadLine | Sort-Object Version -Descending | Select-Object -First 1
            $m -and $m.Version -ge [version]"2.3.0"
        }
        Install     = { Install-Module -Name PSReadLine -Scope CurrentUser -Force -AllowPrerelease }
    }

    'zoxide' = @{
        Label       = "Zoxide        (smart cd — z keyword)"
        Required    = $false
        Selected    = $true
        Deps        = @()
        SoftDeps    = @('winget')
        Check       = { Test-Cmd 'zoxide' }
        Install     = {
            if (Test-Cmd 'winget')     { winget install ajeetdsouza.zoxide --accept-package-agreements --accept-source-agreements | Out-Null }
            elseif (Test-Cmd 'scoop')  { scoop install zoxide }
            else { throw "No package manager available" }
        }
    }

    'git' = @{
        Label       = "Git           (needed for git shortcuts and gh completions)"
        Required    = $false
        Selected    = $false           # only auto-select if missing
        Deps        = @()
        SoftDeps    = @('winget')
        Check       = { Test-Cmd 'git' }
        Install     = {
            if (Test-Cmd 'winget')     { winget install Git.Git --accept-package-agreements --accept-source-agreements | Out-Null }
            elseif (Test-Cmd 'scoop')  { scoop install git }
            else { throw "No package manager available" }
        }
    }

    'gh' = @{
        Label       = "gh CLI        (GitHub CLI — needed for gh Tab completions)"
        Required    = $false
        Selected    = $false
        Deps        = @('git')          # gh requires git
        SoftDeps    = @('winget')
        Check       = { Test-Cmd 'gh' }
        Install     = {
            if (Test-Cmd 'winget')     { winget install GitHub.cli --accept-package-agreements --accept-source-agreements | Out-Null }
            elseif (Test-Cmd 'scoop')  { scoop install gh }
            else { throw "No package manager available" }
        }
    }

    'lazydocker' = @{
        Label       = "lazydocker    (Docker TUI — dmon command)"
        Required    = $false
        Selected    = $false
        Deps        = @('docker')
        SoftDeps    = @('winget')
        Check       = { Test-Cmd 'lazydocker' }
        Install     = {
            if (Test-Cmd 'winget')     { winget install JesseDuffield.lazydocker --accept-package-agreements --accept-source-agreements | Out-Null }
            elseif (Test-Cmd 'scoop')  { scoop install lazydocker }
            else { throw "No package manager available" }
        }
    }

    'burnttoast' = @{
        Label       = "BurntToast    (desktop notifications — notify command)"
        Required    = $false
        Selected    = $false
        Deps        = @()
        SoftDeps    = @()
        Check       = { Get-Module -ListAvailable -Name BurntToast }
        Install     = { Install-Module BurntToast -Scope CurrentUser -Force }
    }
}

# Auto-select git if not installed (needed for core shortcuts)
if (-not $checkResults['git']) { $components['git'].Selected = $true }

# ─── Dependency checker ────────────────────────────────────────────────────────

function Get-UnmetDeps([string]$key) {
    $comp = $components[$key]
    if (-not $comp.ContainsKey('Deps') -or $comp.Deps.Count -eq 0) { return @() }
    return $comp.Deps | Where-Object {
        # dep satisfied if: already installed OR selected for install
        -not $checkResults[$_] -and -not $components[$_].Selected
    }
}

function Get-MissingSoftDeps([string]$key) {
    $comp = $components[$key]
    if (-not $comp.ContainsKey('SoftDeps') -or $comp.SoftDeps.Count -eq 0) { return @() }
    return $comp.SoftDeps | Where-Object { -not $checkResults[$_] }
}

# ─── Interactive menu ──────────────────────────────────────────────────────────

function Show-Menu {
    $keys  = @($components.Keys)
    $index = 0

    while ($true) {
        Write-Header "Phase 2 — Select Components  (SPACE=toggle · ENTER=install · Q=quit)"

        # Package manager status line
        $pkgMgr = if ($checkResults['winget']) { "winget ✓" }
                  elseif ($checkResults['scoop']) { "scoop ✓" }
                  else { "no package manager ✗" }
        Write-Host "  Package manager: $pkgMgr  |  git: $(if($checkResults['git']){'✓'}else{'✗'})  |  docker: $(if($checkResults['docker']){'✓'}else{'✗'})  |  gh: $(if($checkResults['gh (GitHub CLI)']){'✓'}else{'✗'})" -ForegroundColor DarkGray
        Write-Host ""

        for ($i = 0; $i -lt $keys.Count; $i++) {
            $key   = $keys[$i]
            $comp  = $components[$key]
            $sel   = $comp.Selected
            $unmet = Get-UnmetDeps $key
            $softW = Get-MissingSoftDeps $key

            $bullet    = if ($sel) { '●' } else { '○' }
            $bColor    = if ($sel) { 'Cyan' } else { 'DarkGray' }
            $cursor    = if ($i -eq $index) { '▶' } else { ' ' }
            $cColor    = if ($i -eq $index) { 'Yellow' } else { 'DarkGray' }
            $reqTag    = if ($comp.Required) { ' [required]' } else { '' }
            $instTag   = if ($checkResults.ContainsKey($key) -and (&$comp.Check 2>$null)) { ' ✓' } else { '' }
            $depWarn   = if ($unmet)  { " ← needs: $($unmet -join ', ')" } else { '' }
            $softWarn  = if ($softW -and -not $unmet) { " (needs $($softW -join '/'))" } else { '' }

            $lColor = if ($unmet)           { 'DarkGray' }
                      elseif ($i -eq $index) { 'White' }
                      else                  { 'Gray' }

            Write-Host -NoNewline "  $cursor " -ForegroundColor $cColor
            Write-Host -NoNewline "[$bullet] " -ForegroundColor $bColor
            Write-Host -NoNewline $comp.Label -ForegroundColor $lColor
            Write-Host -NoNewline $instTag -ForegroundColor Green
            Write-Host -NoNewline $reqTag -ForegroundColor DarkRed
            if ($depWarn)  { Write-Host -NoNewline $depWarn  -ForegroundColor Red }
            if ($softWarn) { Write-Host -NoNewline $softWarn -ForegroundColor DarkGray }
            Write-Host ""
        }

        Write-Host ""
        Write-Host "  Legend: ● selected  ○ deselected  ✓ already installed  ← unmet dep" -ForegroundColor DarkGray
        Write-Host ""

        $k = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
        switch ($k.VirtualKeyCode) {
            38 { if ($index -gt 0) { $index-- } }
            40 { if ($index -lt ($keys.Count - 1)) { $index++ } }
            32 {
                $key = $keys[$index]
                if (-not $components[$key].Required) {
                    $newSel = -not $components[$key].Selected
                    $components[$key].Selected = $newSel

                    # Auto-select hard deps when enabling
                    if ($newSel -and $components[$key].ContainsKey('Deps')) {
                        foreach ($dep in $components[$key].Deps) {
                            if ($components.ContainsKey($dep) -and -not $checkResults[$dep]) {
                                $components[$dep].Selected = $true
                            }
                        }
                    }
                }
            }
            13 { return $true }
            81 { return $false }
            27 { return $false }
        }
    }
}

# ─── Install ───────────────────────────────────────────────────────────────────

function Start-Install {
    Write-Header "Phase 3 — Installing"

    foreach ($key in $components.Keys) {
        $comp  = $components[$key]
        if (-not $comp.Selected) { Write-Skip $comp.Label; continue }

        Write-Sep
        Write-Host "  $($comp.Label)" -ForegroundColor Cyan

        # Check hard deps one final time
        $unmet = Get-UnmetDeps $key
        if ($unmet) {
            Write-Fail "Skipped — unmet dependencies: $($unmet -join ', ')"
            continue
        }

        $alreadyOk = try { & $comp.Check } catch { $false }
        if ($alreadyOk) {
            Write-OK "Already installed — skipping"
        } else {
            try {
                Write-Info "Installing..."
                & $comp.Install
                Write-OK "Done"
            } catch {
                Write-Fail "Failed: $_"
            }
        }
        Write-Host ""
    }

    Write-Sep
    Write-Host ""
    Write-Host "  Installation complete!" -ForegroundColor Green
    Write-Host ""
    Write-Host "  Reload your profile:" -ForegroundColor Yellow
    Write-Host "    . `$PROFILE" -ForegroundColor White
    Write-Host ""
    Write-Host "  Or open a new terminal window." -ForegroundColor DarkGray
    Write-Host ""
}

# ─── Entry point ───────────────────────────────────────────────────────────────

Write-Header

# --check only
if ($args -contains '--check') {
    $ok = Show-SystemCheck
    exit ($ok ? 0 : 1)
}

# System check
$ok = Show-SystemCheck
if (-not $ok) { exit 1 }

Read-Host "  Press ENTER to continue to component selection"

# --all: no menu
if ($args -contains '--all' -or $args -contains '-y') {
    Write-Info "Non-interactive mode (--all) — installing all defaults..."
    Write-Host ""
    Start-Install
    exit 0
}

# Interactive
$proceed = Show-Menu
if (-not $proceed) {
    Write-Host ""
    Write-Skip "Installation cancelled."
    Write-Host ""
    exit 0
}

Write-Host ""
if (Confirm "Install selected components?") {
    Start-Install
} else {
    Write-Host ""
    Write-Skip "Cancelled."
    Write-Host ""
}
