# LockBlocker

LockBlocker.ps1 is a PowerShell script that prevents the computer from locking by simulating a Scroll Lock key press every 299 seconds. It also displays the execution timestamp and battery status. The script runs indefinitely until manually stopped.

## Usage

1. Save the script as `LockBlocker.ps1`.
2. Open a PowerShell window.
3. Navigate to the directory where the script is saved.
4. Run the script by typing `.\LockBlocker.ps1` and pressing Enter.
5. To stop the script, press `Q` or `Ctrl+C` in the PowerShell window.

## Features

- **Show-DateTime**: Displays the current date and time.
- **Show-BatteryStatus**: Displays the battery status, including charge status and remaining charge.

## Example

```powershell
$host.UI.RawUI.WindowTitle = "Lilith's LockBlocker"

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Keyboard {
    [DllImport("user32.dll", CharSet = CharSet.Auto, ExactSpelling = true)]
    public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int extraInfo);
    public const int KEYEVENTF_EXTENDEDKEY = 0x1;
    public const int KEYEVENTF_KEYUP = 0x2;
    public const int VK_SCROLL = 0x91;
}
"@

$keypressInterval = 299

function Show-DateTime {
    $currentDate = Get-Date
    $formattedDate = $currentDate.ToString("dddd, d. MMMM yyyy HH:mm:ss")
    Write-Host "LockBlocker active." -ForegroundColor Green
    Write-Host "`nLast execution: $formattedDate"
    Write-Host "Block interval every $keypressInterval seconds."
}

function Show-BatteryStatus {
    $battery = Get-CimInstance -ClassName Win32_Battery
    if ($battery) {
        $batteryStatus = if ($battery.BatteryStatus -eq 2) { "Charging" } else { "Not charging" }
        $batteryPercentage = $battery.EstimatedChargeRemaining
        if ($batteryStatus -eq "Charging") {
            Write-Host "Battery status: $batteryStatus" -ForegroundColor Green
        } else {
            Write-Host "Battery status: $batteryStatus" -ForegroundColor DarkYellow
        }
        if ($batteryPercentage -ge 90) {
            Write-Host "Battery charge: $batteryPercentage%" -ForegroundColor Green
        } elseif ($batteryPercentage -le 15) {
            Write-Host "Battery charge: $batteryPercentage%" -ForegroundColor Red
        } else {
            Write-Host "Battery charge: $batteryPercentage%" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nNo battery found. System running on AC power." -ForegroundColor Green
    }
}

while ($true) {
    [Keyboard]::keybd_event([Keyboard]::VK_SCROLL, 0, [Keyboard]::KEYEVENTF_EXTENDEDKEY, 0)
    [Keyboard]::keybd_event([Keyboard]::VK_SCROLL, 0, [Keyboard]::KEYEVENTF_KEYUP, 0)
    Clear-Host
    Show-DateTime
    Show-BatteryStatus
    Start-Sleep -Seconds $keypressInterval
}
```
## License

LockBlocker (c) 2024 by Lilith Frahm, [https://LilithFrahm.de](https://LilithFrahm.de)
