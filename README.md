<div align="center">

<img src="https://raw.githubusercontent.com/jandedobbeleer/oh-my-posh/main/website/static/img/logo.png" width="90" alt="Oh My Posh"/>

# PowerShell Profile — LinhDangDev

**A batteries-included PowerShell profile for Windows web developers.**  
Ghost-text autocomplete · Git one-liners · Yarn/Node shortcuts · Docker utils · Smart `cd` · Auto-ls · Port killer · `.env` loader

[![Profile](https://img.shields.io/badge/profile-1222_lines-blue?logo=powershell&logoColor=white)](./Microsoft.powershell_profile.ps1)
[![Oh My Posh](https://img.shields.io/badge/theme-iterm2-blueviolet?logo=iterm2)](./themes/iterm2.omp.json)
[![License](https://img.shields.io/github/license/LinhDangDev/Config-Oh-My-Posh)](./LICENSE)
[![Windows](https://img.shields.io/badge/platform-Windows_11-0078D4?logo=windows)](.)

</div>

---

## What's inside

| Feature | Command / Key | Description |
|---------|--------------|-------------|
| [Ghost Text Autocomplete](#-autocomplete--keyboard-shortcuts) | `End` / `→` | Inline history suggestions |
| [Enhanced Tab](#-autocomplete--keyboard-shortcuts) | `Tab` | Shows file list with size+date before completing |
| [Auto-ls on cd](#-auto-ls-on-cd) | `cd <path>` | Lists directory contents after every `cd` |
| [Git Shortcuts](#-git-shortcuts) | `gs`, `glog`, `gco`, `gcp` | Common git ops in 2-3 chars |
| [Yarn / Node Shortcuts](#-yarn--node-shortcuts) | `yd`, `yt`, `yb` | Dev/test/build shortcuts |
| [Docker Helpers](#-docker-helpers) | `dps`, `dex`, `dmon` | Colored status, fuzzy exec, TUI |
| [Port Killer](#-utility-functions) | `kp 3000` | Kill any process on a port |
| [.env Loader](#-utility-functions) | `le` | Load `.env` into current session |
| [Pretty ll](#-utility-functions) | `ll` | Colored list with size+date (no Mode column) |
| [Zoxide Smart cd](#-zoxide--smart-cd) | `z vsense` | Jump to frequent dirs by partial name |
| [Unix helpers](#-utility-functions) | `which`, `mkcd`, `up`, `touch` | Unix-style utilities |
| [DB / Drizzle helpers](#-drizzle--db-helpers) | `db-push`, `db-gen` | Drizzle Kit shortcuts |
| [UTF-8 fix](#-utf-8-fix) | automatic | Fixes garbled yarn/vitest output |

---

## Prerequisites

```powershell
# 1. Oh My Posh
winget install JanDeDobbeleer.OhMyPosh -s winget

# 2. A Nerd Font (needed for icons in the prompt)
oh-my-posh font install
# Restart terminal, then set the font in Settings -> Appearance

# 3. Terminal Icons
Install-Module -Name Terminal-Icons -Scope CurrentUser -Force

# 4. PSReadLine (update to latest)
Install-Module -Name PSReadLine -Scope CurrentUser -Force -AllowPrerelease

# 5. Zoxide — smart cd
winget install ajeetdsouza.zoxide

# 6. (Optional) lazydocker TUI
winget install JesseDuffield.lazydocker

# 7. (Optional) Desktop notifications
Install-Module BurntToast -Scope CurrentUser
```

---

## Installation

```powershell
# Clone this repo
git clone https://github.com/LinhDangDev/Config-Oh-My-Posh.git

# Copy profile to your PowerShell profile location
Copy-Item .\Config-Oh-My-Posh\Microsoft.powershell_profile.ps1 $PROFILE -Force

# Copy iterm2 theme (used by default in the profile)
$themeDest = "$env:LOCALAPPDATA\Programs\oh-my-posh\themes\"
Copy-Item .\Config-Oh-My-Posh\themes\iterm2.omp.json $themeDest -Force

# Reload profile
. $PROFILE
```

> **Execution policy error?** Run this first:
> ```powershell
> Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
> ```

---

## 🎯 Autocomplete & Keyboard Shortcuts

![Autocomplete demo](./docs/demo-autocomplete.svg)

### Ghost Text

| Key | Action |
|-----|--------|
| `→` at end of line | Accept **next word** of ghost suggestion |
| `End` | Accept **entire** ghost suggestion |
| `Ctrl+→` | Accept next suggestion word |
| `F2` | Toggle **ghost text** ↔ **list view** history |
| `↑` / `↓` | Search history by current prefix |

### Tab — Enhanced Completion

Pressing `Tab` shows a file/folder list with size and date **before** the menu popup:

```
  <DIR>      2026-05-04 22:49  apps
  <DIR>      2026-04-26 12:05  dist
     4,0 KB  2026-04-26 12:05  package.json
     1,3 KB  2026-05-03 22:46  eslint.config.js
```

| Key | Action |
|-----|--------|
| `Tab` | Show list + cycle file/folder completions |
| `Shift+Tab` | MenuComplete (no list) |
| `F6` | Function picker (Out-GridView) |
| `F7` | Command history picker |
| `Alt+w` | Save line to history without executing |

---

## 📂 Auto-ls on cd

Every `cd` automatically shows the directory contents (Terminal-Icons style):

```powershell
cd apps
#  Mode    LastWriteTime      Length  Name
#  ----    -------------      ------  ----
#  d----   26/04/2026  12:05          api
#  d----   26/04/2026  12:05          web

cd ..            # go up + show ls
cd -             # go back + show ls
cd               # go to $HOME + show ls
```

---

## 🔀 Git Shortcuts

![Git demo](./docs/demo-git-shortcuts.svg)

| Shortcut | Equivalent |
|----------|-----------|
| `gs` | `git status -sb` |
| `glog` | `git log --oneline --graph --decorate -20` |
| `gco <branch>` | `git checkout <branch>` |
| `gcb <name>` | `git checkout -b <name>` |
| `gaa` | `git add -A` |
| `gd` | `git diff` |
| `gp` | `git push` |
| `gpl` | `git pull --rebase` |
| `gst` | `git stash` |
| `gsp` | `git stash pop` |
| `gcp "message"` | `git add -A && git commit -m "..." && git push` |

### Demo

```powershell
# Create and switch to feature branch
gcb feat/r2-upload-health-endpoints
# Switched to a new branch 'feat/r2-upload-health-endpoints'

# Check status
gs
# ## feat/r2-upload-health-endpoints
#  M apps/api/src/modules/uploads/uploads-driver.ts
#  M apps/api/src/modules/uploads/routes.ts

# Pretty log
glog
# * e0c1d20  (HEAD -> feat/r2-upload-health-endpoints)  feat(uploads): add R2 driver
# * 100b0a5  feat(cart,catalog): add health check endpoints
# * 1d1ca86  chore(env): add R2 env vars

# Add, commit, push in one shot
gcp "feat(uploads): add Cloudflare R2 upload driver and health endpoint"
# [feat/r2-upload-health-endpoints e0c1d20] feat(uploads): add Cloudflare R2 upload driver
# -> pushed to origin/feat/r2-upload-health-endpoints
```

> **Autocorrect:** Typing `git cmt` is automatically corrected to `git commit`.

---

## 🧶 Yarn / Node Shortcuts

| Shortcut | Equivalent |
|----------|-----------|
| `yd` | `yarn dev` |
| `yda` | `yarn dev:api` |
| `ydw` | `yarn dev:web` |
| `yt` | `yarn test` |
| `ytw` | `yarn test --watch` |
| `yb` | `yarn build` |
| `yi` | `yarn install` |
| `nvv` | Print `node` + `yarn` versions |

---

## 🐳 Docker Helpers

| Shortcut | Description |
|----------|-------------|
| `dps` | Colored running container table (green=Up, red=Exited) |
| `dex <name>` | `docker exec -it <fuzzy-name> sh` — partial name match |
| `dmon` | Launch `lazydocker` TUI |
| `dl-split <c1> <c2>` | Open container logs side-by-side in new WT panes |
| `dl-paste` | Read `docker logs` commands from clipboard, split panes |

---

## 🛠 Utility Functions

![Utilities demo](./docs/demo-utils.svg)

### `ll` — Pretty directory listing (no Mode column)

```powershell
ll
#   22 dirs  |  24 files  |  2.4 MB
#   -----------------------------------------------------------
#   <DIR>      2026-05-04 22:49  apps          <- cyan
#   <DIR>      2026-04-26 12:05  dist
#      382 B   2026-05-04 16:12  .env          <- red
#      4.0 KB  2026-04-26 12:05  package.json  <- yellow
```

### `kp` — Kill a port

```powershell
kp 3001
# Killed PID 18432 on :3001
```

### `le` — Load `.env` into session

```powershell
le              # loads .env
le .env.local   # loads a specific file
$env:DATABASE_URL   # use any loaded var immediately
```

### `mkcd` — Create directory and `cd` into it

```powershell
mkcd src/features/payments
```

### `up` — Go up N directories

```powershell
up      # go up 1 level
up 3    # go up 3 levels at once
```

### `touch` — Create file (Unix-style)

```powershell
touch src/utils/helpers.ts
```

### `which` — Locate a command

```powershell
which node
# node  Application  C:\Program Files\nodejs\node.exe
```

### `c.` — Open VS Code

```powershell
c.                # current folder
c src/index.ts    # specific file
```

### `show-env` — List env vars with optional filter

```powershell
show-env DATABASE
# DATABASE_URL  postgresql://localhost:5432/vsense_dev
```

### `notify` — Desktop notification after long command

```powershell
notify { yarn build }
# Windows toast: "Task finished — Completed in 12.3s"
```

### `duf` — Folder sizes (recursive)

```powershell
duf
# Folder         Size      Items
# ------         ----      -----
# apps           12.40 MB  342
# node_modules   487.20 MB 18432
```

---

## 🗄 Drizzle / DB Helpers

| Shortcut | Equivalent |
|----------|-----------|
| `db-push` | `yarn drizzle-kit push` |
| `db-gen` | `yarn drizzle-kit generate` |
| `db-studio` | `yarn drizzle-kit studio` |

---

## ⚡ Zoxide — Smart `cd`

```powershell
# Install once:
winget install ajeetdsouza.zoxide

# Usage — jumps to the most-visited matching path:
z vsense     # -> D:\Vsense\Vsense_Shop\Eccomere\Vsense_Shop
z api        # -> ...\apps\api
z docs       # -> whichever docs folder you visit most
```

---

## 🔤 UTF-8 Fix

Fixes garbled output (`Γ£ô` -> `✓`) from `yarn`, `vitest`, `node` on Windows.

```powershell
[Console]::InputEncoding  = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$OutputEncoding           = [System.Text.Encoding]::UTF8
chcp 65001 | Out-Null
$env:LANG       = "en_US.UTF-8"
$env:PYTHONUTF8 = "1"
```

---

## 🔄 Keeping the profile in sync

After editing `$PROFILE` locally, push changes back to this repo:

```powershell
git clone https://github.com/LinhDangDev/Config-Oh-My-Posh.git
Copy-Item $PROFILE .\Config-Oh-My-Posh\Microsoft.powershell_profile.ps1 -Force
cd Config-Oh-My-Posh
git add Microsoft.powershell_profile.ps1
git commit -m "feat(profile): describe your changes"
git push origin main
```

---

<div align="center">
  <sub>Built with <a href="https://ohmyposh.dev">Oh My Posh</a> · <a href="https://github.com/PowerShell/PSReadLine">PSReadLine</a> · <a href="https://github.com/ajeetdsouza/zoxide">zoxide</a> · <a href="https://github.com/devblackops/Terminal-Icons">Terminal-Icons</a></sub>
</div>
