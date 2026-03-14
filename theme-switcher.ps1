Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Needed to broadcast WM_SETTINGCHANGE so apps update in real time
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class WinTheme {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern IntPtr SendMessageTimeout(
        IntPtr hWnd, uint Msg, UIntPtr wParam, string lParam,
        uint fuFlags, uint uTimeout, out UIntPtr lpdwResult);
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern bool SystemParametersInfo(
        uint uAction, uint uParam, string lpvParam, uint fuWinIni);
    public static readonly IntPtr HWND_BROADCAST = new IntPtr(0xffff);
    public const uint WM_SETTINGCHANGE = 0x001A;
    public const uint SMTO_ABORTIFHUNG = 0x0002;
    public const uint SPI_SETDESKWALLPAPER = 0x0014;
    public const uint SPIF_UPDATEINIFILE = 0x0001;
    public const uint SPIF_SENDCHANGE = 0x0002;
}
"@

$REGISTRY_KEY = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

# --- Wallpaper paths ---
$WallpaperDark  = "C:\WINDOWS\web\wallpaper\Windows\img19.jpg"
$WallpaperLight = "C:\WINDOWS\web\wallpaper\Windows\img0.jpg"

function Get-CurrentMode {
    $value = (Get-ItemProperty -Path $REGISTRY_KEY -Name AppsUseLightTheme).AppsUseLightTheme
    if ($value -eq 1) { return "light" } else { return "dark" }
}

function Set-Wallpaper($path) {
    if ($path -and (Test-Path $path)) {
        [WinTheme]::SystemParametersInfo(
            [WinTheme]::SPI_SETDESKWALLPAPER, 0, $path,
            [WinTheme]::SPIF_UPDATEINIFILE -bor [WinTheme]::SPIF_SENDCHANGE) | Out-Null
    }
}

function Set-Mode($mode) {
    $value = if ($mode -eq "light") { 1 } else { 0 }
    Set-ItemProperty -Path $REGISTRY_KEY -Name AppsUseLightTheme -Value $value
    # Broadcast so Explorer, taskbar, and apps react immediately
    $dummy = [UIntPtr]::Zero
    [WinTheme]::SendMessageTimeout(
        [WinTheme]::HWND_BROADCAST, [WinTheme]::WM_SETTINGCHANGE,
        [UIntPtr]::Zero, "ImmersiveColorSet",
        [WinTheme]::SMTO_ABORTIFHUNG, 5000, [ref]$dummy) | Out-Null
    # Switch wallpaper
    if ($mode -eq "dark") { Set-Wallpaper $WallpaperDark } else { Set-Wallpaper $WallpaperLight }
}

function New-TrayIcon($mode) {
    $size = 32
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

    if ($mode -eq "dark") {
        $g.Clear([System.Drawing.Color]::FromArgb(30, 30, 46))
        # Moon: white disc with a cutout
        $moonBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(220, 220, 255))
        $bgBrush   = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(30, 30, 46))
        $g.FillEllipse($moonBrush, 4, 4, 24, 24)
        $g.FillEllipse($bgBrush, 11, 1, 20, 20)
        $moonBrush.Dispose(); $bgBrush.Dispose()
    } else {
        $g.Clear([System.Drawing.Color]::FromArgb(135, 206, 235))
        $sunBrush = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(255, 210, 0))
        $pen      = New-Object System.Drawing.Pen([System.Drawing.Color]::FromArgb(255, 210, 0), 2.5)
        # Rays
        $cx = 16; $cy = 16
        for ($angle = 0; $angle -lt 360; $angle += 45) {
            $rad = $angle * [Math]::PI / 180
            $x1  = $cx + 8  * [Math]::Cos($rad)
            $y1  = $cy + 8  * [Math]::Sin($rad)
            $x2  = $cx + 14 * [Math]::Cos($rad)
            $y2  = $cy + 14 * [Math]::Sin($rad)
            $g.DrawLine($pen, [float]$x1, [float]$y1, [float]$x2, [float]$y2)
        }
        # Sun body
        $g.FillEllipse($sunBrush, 10, 10, 12, 12)
        $sunBrush.Dispose(); $pen.Dispose()
    }

    $g.Dispose()
    $icon = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    $bmp.Dispose()
    return $icon
}

function Get-TitleCase($s) {
    return $s.Substring(0, 1).ToUpper() + $s.Substring(1)
}

# --- Build tray icon ---
$tray      = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon = New-TrayIcon (Get-CurrentMode)
$tray.Text = "Theme: $(Get-TitleCase (Get-CurrentMode))"
$tray.Visible = $true

# --- Context menu ---
$menu       = New-Object System.Windows.Forms.ContextMenuStrip
$itemToggle = $menu.Items.Add("Toggle Dark / Light Mode")
$menu.Items.Add("-") | Out-Null
$itemQuit   = $menu.Items.Add("Quit")

$tray.ContextMenuStrip = $menu

$doToggle = {
    $newMode  = if ((Get-CurrentMode) -eq "light") { "dark" } else { "light" }
    Set-Mode $newMode
    $tray.Icon = New-TrayIcon $newMode
    $tray.Text = "Theme: $(Get-TitleCase $newMode)"
}

$itemToggle.add_Click($doToggle)
$tray.add_DoubleClick($doToggle)

$itemQuit.add_Click({
    $tray.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})

[System.Windows.Forms.Application]::Run()
$tray.Dispose()
