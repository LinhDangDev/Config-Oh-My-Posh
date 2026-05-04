#Requires -Version 7
<#
.SYNOPSIS
    PowerShell Profile Installer v0.0.1
.DESCRIPTION
    Interactive installer for LinhDangDev's PowerShell profile.
    Select which components to install, then confirm.
.LINK
    https://github.com/LinhDangDev/Config-Oh-My-Posh
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$VERSION  = "0.0.1"
$REPO_URL = "https://github.com/LinhDangDev/Config-Oh-My-Posh"
$SCRIPT_DIR = $PSScriptRoot

# ─── Helpers ──────────────────────────────────────────────────────────────────

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║   PowerShell Profile Installer  v$VERSION          ║" -ForegroundColor Cyan
    Write-Host "  ║   $REPO_URL  ║" -ForegroundColor DarkGray
    Write-Host "  ╚══════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step([string]$msg) {
    Write-Host "  → $msg" -ForegroundColor Yellow
}

function Write-OK([string]$msg) {
    Write-Host "  ✓ $msg" -ForegroundColor Green
}

function Write-Skip([string]$msg) {
    Write-Host "  ○ $msg" -ForegroundColor DarkGray
}

function Write-Fail([string]$msg) {
    Write-Host "  ✗ $msg" -ForegroundColor Red
}

function Confirm-Action([string]$prompt) {
    $ans = Read-Host "  $prompt [Y/n]"
    return ($ans -eq '' -or $ans -match '^[Yy]')
}

function Test-Command([string]$name) {
    return [bool](Get-Command $name -ErrorAction SilentlyContinue)
}

# ─── Component definitions ────────────────────────────────────────────────────

$components = [ordered]@{
    "profile"       = @{
        Label       = "Core Profile (PSReadLine, UTF-8, git/yarn shortcuts, auto-ls)"
        Required    = $true
        Selected    = $true
        Description = "Main profile file — required for everything else"
        Check       = { $true }
        Install     = {
            $dest = $PROFILE
            $dir  = Split-Path $dest
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            Copy-Item "$SCRIPT_DIR\Microsoft.powershell_profile.ps1" $dest -Force
        }
    }
    "ohmyposh"      = @{
        Label       = "Oh My Posh  (prompt theme — requires Nerd Font)"
        Required    = $false
        Selected    = $true
        Description = "Beautiful prompt with git status, time, icons"
        Check       = { Test-Command 'oh-my-posh' }
        Install     = {
            Write-Step "Installing Oh My Posh via winget..."
            winget install JanDeDobbeleer.OhMyPosh -s winget --accept-package-agreements --accept-source-agreements | Out-Null
            $themeSrc  = "$SCRIPT_DIR\themes\iterm2.omp.json"
            $themeDest = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\"
            if (Test-Path $themeSrc) {
                New-Item -ItemType Directory -Path $themeDest -Force | Out-Null
                Copy-Item $themeSrc $themeDest -Force
            }
        }
    }
    "nerd-font"     = @{
        Label       = "Nerd Font   (CaskaydiaCove — needed for icons)"
        Required    = $false
        Selected    = $true
        Description = "Font with icons for Oh My Posh and Terminal-Icons"
        Check       = {
            (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -ErrorAction SilentlyContinue).PSObject.Properties.Name |
                Where-Object { $_ -match 'Cascadia|CaskaydiaCove|Nerd' } | Select-Object -First 1
        }
        Install     = {
            Write-Step "Installing CaskaydiaCove Nerd Font via Oh My Posh..."
            oh-my-posh font install CascadiaCode
        }
    }
    "terminal-icons" = @{
        Label       = "Terminal-Icons  (file icons in ls/ll output)"
        Required    = $false
        Selected    = $true
        Description = "Adds colored icons to Get-ChildItem output"
        Check       = { Get-Module -ListAvailable -Name Terminal-Icons }
        Install     = {
            Write-Step "Installing Terminal-Icons module..."
            Install-Module -Name Terminal-Icons -Scope CurrentUser -Force
        }
    }
    "psreadline"    = @{
        Label       = "PSReadLine   (autocomplete, ghost text, syntax colors)"
        Required    = $false
        Selected    = $true
        Description = "Latest PSReadLine for InlineView predictions"
        Check       = {
            $m = Get-Module -ListAvailable -Name PSReadLine | Sort-Object Version -Descending | Select-Object -First 1
            $m -and $m.Version -ge [version]"2.3.0"
        }
        Install     = {
            Write-Step "Updating PSReadLine to latest pre-release..."
            Install-Module -Name PSReadLine -Scope CurrentUser -Force -AllowPrerelease
        }
    }
    "zoxide"        = @{
        Label       = "Zoxide       (smart cd — z <keyword> to jump)"
        Required    = $false
        Selected    = $true
        Description = "Replaces cd with frecency-based directory jumping"
        Check       = { Test-Command 'zoxide' }
        Install     = {
            Write-Step "Installing zoxide via winget..."
            winget install ajeetdsouza.zoxide --accept-package-agreements --accept-source-agreements | Out-Null
        }
    }
    "lazydocker"    = @{
        Label       = "lazydocker   (Docker TUI — dmon command)"
        Required    = $false
        Selected    = $false
        Description = "Terminal UI for managing Docker containers"
        Check       = { Test-Command 'lazydocker' }
        Install     = {
            Write-Step "Installing lazydocker via winget..."
            winget install JesseDuffield.lazydocker --accept-package-agreements --accept-source-agreements | Out-Null
        }
    }
    "burnttoast"    = @{
        Label       = "BurntToast   (desktop notifications — notify command)"
        Required    = $false
        Selected    = $false
        Description = "Windows 10/11 toast notifications for long-running commands"
        Check       = { Get-Module -ListAvailable -Name BurntToast }
        Install     = {
            Write-Step "Installing BurntToast module..."
            Install-Module BurntToast -Scope CurrentUser -Force
        }
    }
}

# ─── Interactive selector ──────────────────────────────────────────────────────

function Show-Menu {
    $keys  = @($components.Keys)
    $index = 0

    while ($true) {
        Write-Header
        Write-Host "  Use ↑↓ to navigate, SPACE to toggle, ENTER to install, Q to quit" -ForegroundColor DarkGray
        Write-Host ""

        for ($i = 0; $i -lt $keys.Count; $i++) {
            $key  = $keys[$i]
            $comp = $components[$key]
            $sel  = if ($comp.Selected) { "●" } else { "○" }
            $selColor = if ($comp.Selected) { "Cyan" } else { "DarkGray" }
            $reqTag = if ($comp.Required) { " [required]" } else { "" }
            $cursor = if ($i -eq $index) { "▶" } else { " " }

            Write-Host -NoNewline "  $cursor " -ForegroundColor (if ($i -eq $index) { "Yellow" } else { "DarkGray" })
            Write-Host -NoNewline "[$sel] " -ForegroundColor $selColor
            Write-Host -NoNewline $comp.Label -ForegroundColor (if ($i -eq $index) { "White" } else { "Gray" })
            Write-Host $reqTag -ForegroundColor DarkRed
        }

        Write-Host ""
        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

        switch ($key.VirtualKeyCode) {
            38 { if ($index -gt 0) { $index-- } }                          # Up
            40 { if ($index -lt ($keys.Count - 1)) { $index++ } }          # Down
            32 {                                                             # Space
                $k = $keys[$index]
                if (-not $components[$k].Required) {
                    $components[$k].Selected = -not $components[$k].Selected
                }
            }
            13 { return $true  }   # Enter
            81 { return $false }   # Q
            27 { return $false }   # Escape
        }
    }
}

# ─── Install flow ──────────────────────────────────────────────────────────────

function Start-Install {
    Write-Header
    Write-Host "  Installing selected components..." -ForegroundColor Cyan
    Write-Host ""

    foreach ($key in $components.Keys) {
        $comp = $components[$key]
        if (-not $comp.Selected) { Write-Skip $comp.Label; continue }

        Write-Host "  ─── $($comp.Label)" -ForegroundColor Cyan

        $alreadyInstalled = & $comp.Check
        if ($alreadyInstalled) {
            Write-OK "Already installed — skipping"
        } else {
            try {
                & $comp.Install
                Write-OK "Done"
            } catch {
                Write-Fail "Failed: $_"
            }
        }
        Write-Host ""
    }

    Write-Host "  ══════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  Reload your profile to apply changes:" -ForegroundColor Yellow
    Write-Host "    . `$PROFILE" -ForegroundColor White
    Write-Host ""
    Write-Host "  Or open a new terminal window." -ForegroundColor DarkGray
    Write-Host ""
}

# ─── Entry point ───────────────────────────────────────────────────────────────

Write-Header

# Non-interactive mode: install all defaults without prompts
if ($args -contains '--all' -or $args -contains '-y') {
    Write-Host "  Running in non-interactive mode (--all)..." -ForegroundColor Yellow
    Write-Host ""
    Start-Install
    exit 0
}

# Interactive menu
$proceed = Show-Menu
if (-not $proceed) {
    Write-Host ""
    Write-Host "  Installation cancelled." -ForegroundColor DarkGray
    Write-Host ""
    exit 0
}

Write-Host ""
if (Confirm-Action "Install selected components?") {
    Start-Install
} else {
    Write-Host ""
    Write-Host "  Cancelled." -ForegroundColor DarkGray
    Write-Host ""
}
