<div align="center">

<img src="https://raw.githubusercontent.com/jandedobbeleer/oh-my-posh/main/website/static/img/logo.png" width="90" alt="Oh My Posh"/>

# PowerShell Profile — LinhDangDev

**A batteries-included PowerShell profile for Windows web developers.**  
Ghost-text autocomplete · Git one-liners · Yarn/Node shortcuts · Docker utils · Smart `cd` · Auto-ls · Port killer · `.env` loader

[![Profile](https://img.shields.io/badge/profile-1200%2B_lines-blue?logo=powershell&logoColor=white)](./Microsoft.powershell_profile.ps1)
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
| [Zoxide Smart cd](#-zoxide--smart-cd) | `z <keyword>` | Jump to frequent dirs by partial name |
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
  <DIR>      2026-01-15 09:30  src
  <DIR>      2026-01-10 14:22  public
     4.0 KB  2026-01-15 09:30  package.json
     1.2 KB  2026-01-12 11:05  tsconfig.json
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
cd src
#  Mode    LastWriteTime      Length  Name
#  ----    -------------      ------  ----
#  d----   15/01/2026  09:30          components
#  d----   15/01/2026  09:30          utils
#  -a---   15/01/2026  09:30    1024  index.ts

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
# Create and switch to a new feature branch
gcb feat/user-authentication
# Switched to a new branch 'feat/user-authentication'

# Check what changed
gs
# ## feat/user-authentication
#  M src/modules/auth/auth.service.ts
#  A src/modules/auth/strategies/jwt.strategy.ts

# Pretty commit history
glog
# * a1b2c3d  (HEAD -> feat/user-authentication)  feat(auth): add JWT strategy
# * 9f8e7d6  feat(auth): scaffold auth module
# * 5c4b3a2  chore: init project

# Stage, commit and push in one command
gcp "feat(auth): implement login and register endpoints"
# [feat/user-authentication a1b2c3d] feat(auth): implement login and register endpoints
# -> pushed to origin/feat/user-authentication
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

```powershell
nvv
# node v22.14.0  yarn 4.5.0

yt
#  Test Files  12 passed (12)
#       Tests  84 passed (84)
```

---

## 🐳 Docker Helpers

| Shortcut | Description |
|----------|-------------|
| `dps` | Colored running container table (green=Up, red=Exited) |
| `dex <name>` | `docker exec -it <fuzzy-name> sh` — partial name match |
| `dmon` | Launch `lazydocker` TUI |
| `dl-split <c1> <c2>` | Open container logs side-by-side in new WT panes |

```powershell
dps
# NAME          STATUS    PORTS
# my-api        Up 2h     0.0.0.0:3000->3000/tcp   <- green
# my-postgres   Up 2h     0.0.0.0:5432->5432/tcp   <- green
# my-redis      Exited    -                         <- red

# Exec into container using partial name
dex api
# Runs: docker exec -it my-api sh
```

---

## 🛠 Utility Functions

![Utilities demo](./docs/demo-utils.svg)

### `ll` — Pretty directory listing (no Mode column)

```powershell
ll
#   3 dirs  |  5 files  |  12.4 KB
#   -----------------------------------------------------------
#   <DIR>      2026-01-15 09:30  src          <- cyan
#   <DIR>      2026-01-10 14:22  public
#      1.2 KB  2026-01-12 11:05  .env         <- red
#      4.0 KB  2026-01-15 09:30  package.json <- yellow
```

### `kp` — Kill a port

```powershell
kp 3000
# Killed PID 12345 on :3000
```

### `le` — Load `.env` into session

```powershell
le              # loads .env
le .env.local   # loads a specific file

$env:DATABASE_URL   # use any loaded var immediately
```

### `mkcd` — Create directory and `cd` into it

```powershell
mkcd src/features/auth
# Created + navigated in one step
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

### `show-env` — List env vars with filter

```powershell
show-env DB
# DB_HOST  localhost
# DB_PORT  5432
# DB_NAME  myapp_dev
```

### `notify` — Desktop notification after long command

```powershell
notify { yarn build }
# Windows toast: "Task finished — Completed in 18.4s"
```

### `duf` — Folder sizes (recursive)

```powershell
duf
# Folder         Size      Items
# ------         ----      -----
# node_modules   487.20 MB 18432
# src            2.40 MB   342
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

# After visiting dirs a few times, jump with partial name:
z myapp      # -> C:\Users\Dev\projects\my-awesome-app
z api        # -> ...\src\api
z components # -> whichever components folder you visit most
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
