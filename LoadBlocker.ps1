#
# LockBlocker.ps1 (c) 2024 by Lilith Frahm, https://LilithFrahm.de
#
# This script prevents the computer from locking by simulating a scroll lock key press every 299 seconds.
# It also displays the execution timestamp and the battery status.
# The script runs indefinitely until it is stopped manually.
# 
# Usage:
# 1. Save the script as LockBlocker.ps1
# 2. Open a PowerShell window
# 3. Navigate to the directory where the script is saved
# 4. Run the script by typing .\LockBlocker.ps1 and pressing Enter
# 5. To stop the script, press Ctrl+C in the PowerShell window
#

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
    Write-Host "LockBlocker aktiv." -ForegroundColor Green
    Write-Host "`nLetzte Ausführung: $formattedDate"
    Write-Host "Blockintervall alle $keypressInterval Sekunden."
}

function Show-BatteryStatus {
    $battery = Get-CimInstance -ClassName Win32_Battery
    if ($battery) {
        $batteryStatus = if ($battery.BatteryStatus -eq 2) { "Lädt" } else { "Nicht ladend" }
        $batteryPercentage = $battery.EstimatedChargeRemaining

        if ($batteryStatus -eq "Lädt") {
            Write-Host "Akkustatus: $batteryStatus" -ForegroundColor Green
        } else {
            Write-Host "Akkustatus: $batteryStatus" -ForegroundColor DarkYellow
        }

        if ($batteryPercentage -ge 90) {
            Write-Host "Akkuladung: $batteryPercentage%" -ForegroundColor Green
        } elseif ($batteryPercentage -le 15) {
            Write-Host "Akkuladung: $batteryPercentage%" -ForegroundColor Red
        } else {
            Write-Host "Akkuladung: $batteryPercentage%" -ForegroundColor Yellow
        }
    } else {
        Write-Host "`nKein Akku gefunden. System läuft im Netzbetrieb." -ForegroundColor Green
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