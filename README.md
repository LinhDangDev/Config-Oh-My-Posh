
<!-- markdownlint-disable -->
<p align="center">
  <img
    width="400"
    src="https://raw.githubusercontent.com/jandedobbeleer/oh-my-posh/main/website/static/img/logo.png"
    alt="Oh My Posh – Prompt theme engine for any shell"
  />
</p>
<!-- markdownlint-enable -->
#Document


## Set up your terminal

While Oh My Posh works on the standard terminal, we advise using the [Windows Terminal][wt].

<a href="ms-windows-store://pdp/?productid=XP8K0HKJFRXGCK" target="_blank">
  <img
    src={require('/img/winstore.png').default}
    alt="Windows Store Link"
    className="winstore"
  />
</a>

## Installation

<Tabs
  defaultValue="winget"
  groupId="install"
  values={[
    { label: 'winget', value: 'winget', },
    { label: 'scoop', value: 'scoop', },
    { label: 'manual', value: 'manual', },
  ]
}>
<TabItem value="winget">

Open a PowerShell prompt and run the following command:

```powershell
winget install JanDeDobbeleer.OhMyPosh -s winget
```

</TabItem>
<TabItem value="scoop">

Open a PowerShell prompt and run the following command:

```powershell
scoop install https://github.com/JanDeDobbeleer/oh-my-posh/releases/latest/download/oh-my-posh.json
```

</TabItem>
<TabItem value="manual">

Open a PowerShell prompt and run the following command:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
```

</TabItem>
</Tabs>

This installs a couple of things:

- `oh-my-posh.exe` - Windows executable
- `themes` - The latest Oh My Posh [themes][themes]

For the `PATH` to be reloaded, a restart of your terminal is advised.

:::tip Antivirus software
Due to frequent updates of Oh My Posh, Antivirus software occasionally flags it (false positive).
To ensure Oh My Posh isn't blocked you can either report it to your favorite Antivirus software as false positive
(e.g. [Report a false positive/negative to Microsoft for analysis][report-false-positive]) or create an exclusion for it.
Exclusions should be added with the full path to the executable, you can get it with the following command from a PowerShell prompt:

```powershell
(Get-Command oh-my-posh).Source
```
:::

<Next />

## Update

<Tabs
  defaultValue="winget"
  groupId="install"
  values={[
    { label: 'winget', value: 'winget', },
    { label: 'scoop', value: 'scoop', },
    { label: 'manual', value: 'manual', },
  ]
}>
<TabItem value="winget">

Open a PowerShell prompt and run the following command:

```powershell
winget upgrade JanDeDobbeleer.OhMyPosh -s winget
```

</TabItem>
<TabItem value="scoop">

Open a PowerShell prompt and run the following command:

```powershell
scoop update oh-my-posh
```

</TabItem>
<TabItem value="manual">

Open a PowerShell prompt and run the following command:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force; Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://ohmyposh.dev/install.ps1'))
```

</TabItem>
</Tabs>

## Default themes

You can find the themes in the folder indicated by the environment variable `POSH_THEMES_PATH`.
For example, you can use `oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\jandedobbeleer.omp.json"`
for the prompt initialization in PowerShell.


[fonts]: /docs/installation/fonts
[scoop]: https://scoop.sh/
[wt]: https://github.com/microsoft/terminal
[linux]: /docs/installation/linux
[themes]: /docs/themes
[report-false-positive]: https://docs.microsoft.com/en-us/microsoft-365/security/defender/m365d-autoir-report-false-positives-negatives#report-a-false-positivenegative-to-microsoft-for-analysis
