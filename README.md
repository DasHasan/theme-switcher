# theme-switcher

A minimal Windows system tray utility to toggle between light and dark **app mode** with a single click. The taskbar and Start menu stay unaffected (always dark).

## How it works

Writes `AppsUseLightTheme` in `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize` and broadcasts `WM_SETTINGCHANGE` so apps (Explorer, IntelliJ, browsers, etc.) update in real time — same as Windows Settings does.

## Usage

Double-click `launch.vbs` to start. The icon appears in the system tray.

| Action | Effect |
|---|---|
| Double-click icon | Toggle light / dark |
| Right-click → Toggle | Toggle light / dark |
| Right-click → Quit | Exit |

## Auto-start with Windows

Drop a shortcut to `launch.vbs` into your startup folder:

```
Win + R → shell:startup
```

## Requirements

- Windows 10 / 11
- PowerShell 5.1+ (built-in)

If you see an execution policy error, run once in an admin PowerShell:

```powershell
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```
