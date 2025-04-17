#
# LockBlocker.ps1 (c) 2024 by Lilith Frahm, https://LilithFrahm.de
#
<#
.SYNOPSIS
    Prevents the computer from locking by simulating key presses at configurable intervals.

.DESCRIPTION
    This script prevents the computer from locking by simulating a key press at configurable intervals.
    It also displays the execution timestamp and battery status.
    The script runs until manually stopped by pressing 'Q' or Ctrl+C.

.PARAMETER Interval
    Specifies the interval in seconds between key presses. Default is 299 seconds.

.PARAMETER KeyToPress
    Specifies which key to simulate pressing. Default is ScrollLock.
    Valid options: ScrollLock, F15-F24, NumLock, CapsLock

.PARAMETER DisableToast
    Disables toast notifications even if BurntToast module is available.

.EXAMPLE
    .\LockBlocker.ps1
    Runs the script with default settings (299 second interval, ScrollLock key)

.EXAMPLE
    .\LockBlocker.ps1 -Interval 60 -KeyToPress F15
    Runs the script with 60 second interval using F15 key

.EXAMPLE
    .\LockBlocker.ps1 -DisableToast
    Runs the script with toast notifications disabled

.NOTES
    BurntToast Support:
    If the BurntToast module is installed, it will be used to show toast notifications.
    To install BurntToast: Install-Module -Name BurntToast -Scope CurrentUser
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $false, HelpMessage = "Time interval between key presses in seconds")]
    [ValidateRange(1, 3600)]
    [int]$Interval = 299,
    
    [Parameter(Mandatory = $false, HelpMessage = "Key to simulate pressing")]
    [ValidateSet('ScrollLock', 'F15', 'F16', 'F17', 'F18', 'F19', 'F20', 'F21', 'F22', 'F23', 'F24', 'NumLock', 'CapsLock')]
    [string]$KeyToPress = 'ScrollLock',
    
    [Parameter(Mandatory = $false, HelpMessage = "Disable toast notifications")]
    [switch]$DisableToast = $false
)

#region Configuration and Setup

# Initialize constants and variables
$script:windowTitle = "Lilith's LockBlocker"
$script:isRunning = $true
$script:burntToastAvailable = $false

# Set window title
$host.UI.RawUI.WindowTitle = $script:windowTitle

# Define virtual key codes lookup table
$script:virtualKeyCodes = @{
    'ScrollLock' = 0x91
    'F15' = 0x7E
    'F16' = 0x7F
    'F17' = 0x80
    'F18' = 0x81
    'F19' = 0x82
    'F20' = 0x83
    'F21' = 0x84
    'F22' = 0x85
    'F23' = 0x86
    'F24' = 0x87
    'NumLock' = 0x90
    'CapsLock' = 0x14
}

# Add type definition for simulating key presses
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class Keyboard {
    [DllImport("user32.dll", CharSet = CharSet.Auto, ExactSpelling = true)]
    public static extern void keybd_event(byte bVk, byte bScan, int dwFlags, int extraInfo);
    public const int KEYEVENTF_EXTENDEDKEY = 0x1;
    public const int KEYEVENTF_KEYUP = 0x2;
}
"@

#endregion Configuration and Setup

#region Helper Functions

<#
.SYNOPSIS
    Checks for BurntToast module availability and loads it if possible.
.OUTPUTS
    Boolean indicating whether BurntToast is available for use.
#>
function Initialize-BurntToastSupport {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    $toastAvailable = $false
    
    # No need to continue if toast notifications are disabled
    if ($DisableToast) {
        Write-Host "Toast notifications are disabled by parameter" -ForegroundColor Cyan
        return $false
    }
    
    # Check if BurntToast is already loaded
    if (Get-Module -Name BurntToast) {
        Write-Host "BurntToast module is already loaded" -ForegroundColor Green
        $toastAvailable = $true
    } 
    # Check if BurntToast is installed but not loaded
    elseif (Get-Module -ListAvailable -Name BurntToast) {
        try {
            Write-Host "Loading BurntToast module..." -ForegroundColor Cyan
            Import-Module -Name BurntToast -ErrorAction Stop
            if (Get-Module -Name BurntToast) {
                Write-Host "BurntToast module loaded successfully" -ForegroundColor Green
                $toastAvailable = $true
            } else {
                Write-Host "Failed to load BurntToast module" -ForegroundColor Yellow
                $toastAvailable = $false
            }
        }
        catch {
            Write-Host "Error loading BurntToast module: $($_.Exception.Message)" -ForegroundColor Yellow
            $toastAvailable = $false
        }
    }
    # BurntToast is not installed
    else {
        Write-Host "BurntToast module is not installed" -ForegroundColor Yellow
        $toastAvailable = $false
    }
    
    # Test toast notification if available
    if ($toastAvailable) {
        try {
            Write-Host "Sending test toast notification..." -ForegroundColor Cyan
            New-BurntToastNotification -Text "LockBlocker", "Test notification - BurntToast is working!" -ErrorAction Stop
            Write-Host "Test toast notification sent. If you don't see it, check your Windows notification settings." -ForegroundColor Green
        }
        catch {
            Write-Host "Error sending test toast notification: $($_.Exception.Message)" -ForegroundColor Red
            Write-Host "BurntToast is installed but not working correctly. Try reinstalling with:" -ForegroundColor Red
            Write-Host "Uninstall-Module -Name BurntToast -AllVersions; Install-Module -Name BurntToast -Scope CurrentUser -Force" -ForegroundColor Yellow
            $toastAvailable = $false
        }
    }
    
    return $toastAvailable
}

<#
.SYNOPSIS
    Simulates a key press.
.PARAMETER KeyCode
    Virtual key code for the key to press.
#>
function Invoke-KeyPress {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [byte]$KeyCode
    )
    
    try {
        [Keyboard]::keybd_event($KeyCode, 0, [Keyboard]::KEYEVENTF_EXTENDEDKEY, 0)
        [Keyboard]::keybd_event($KeyCode, 0, [Keyboard]::KEYEVENTF_KEYUP, 0)
    }
    catch {
        Write-Error "Failed to simulate key press: $($_.Exception.Message)"
        throw
    }
}

<#
.SYNOPSIS
    Displays current status information including date, time and settings.
#>
function Show-StatusInformation {
    [CmdletBinding()]
    param()
    
    $currentDate = Get-Date
    $formattedDate = $currentDate.ToString("dddd, d MMMM yyyy HH:mm:ss")
    
    Write-Host "LockBlocker active." -ForegroundColor Green
    
    # Display BurntToast status
    Write-Host -NoNewline "BurntToast Status: "
    if ($script:burntToastAvailable) {
        Write-Host "LOADED" -ForegroundColor Green
    } else {
        if (Get-Module -ListAvailable -Name BurntToast) {
            Write-Host "INSTALLED but not loaded" -ForegroundColor DarkYellow
        } else {
            Write-Host "NOT INSTALLED" -ForegroundColor Red
        }
    }
    
    Write-Host "`nLast run: $formattedDate"
    Write-Host "Using key: $KeyToPress | Interval: every $Interval seconds."
    Write-Host "Press 'Q' to quit."
}

<#
.SYNOPSIS
    Displays battery status information.
#>
function Show-BatteryStatus {
    [CmdletBinding()]
    param()
    
    $battery = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
    
    if (-not $battery) {
        Write-Host "`nNo battery found. System running on AC power." -ForegroundColor Green
        return
    }
    
    $batteryStatus = if ($battery.BatteryStatus -eq 2) { "Charging" } else { "Not charging" }
    $batteryPercentage = $battery.EstimatedChargeRemaining

    if ($batteryStatus -eq "Charging") {
        Write-Host "Battery status: $batteryStatus" -ForegroundColor Green
    } else {
        Write-Host "Battery status: $batteryStatus" -ForegroundColor DarkYellow
    }

    if ($batteryPercentage -ge 90) {
        Write-Host "Battery level: $batteryPercentage%" -ForegroundColor Green
    } elseif ($batteryPercentage -le 15) {
        Write-Host "Battery level: $batteryPercentage%" -ForegroundColor Red

        # Warn with a toast notification if available
        if ($script:burntToastAvailable) {
            try {
                New-BurntToastNotification -Text "Warning!", "Battery critically low: $batteryPercentage%" -ErrorAction SilentlyContinue
            }
            catch {
                # Silently continue if toast notification fails
            }
        }
    } else {
        Write-Host "Battery level: $batteryPercentage%" -ForegroundColor Yellow
    }
}

<#
.SYNOPSIS
    Checks if user pressed the quit key.
.OUTPUTS
    Boolean indicating whether the quit key was pressed.
#>
function Test-QuitKeyPressed {
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    
    if ([Console]::KeyAvailable) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq 'Q') {
            return $true
        }
    }
    return $false
}

<#
.SYNOPSIS
    Shows initial configuration information.
#>
function Show-ConfigurationInfo {
    [CmdletBinding()]
    param()
    
    Write-Host "LockBlocker starting with the following settings:" -ForegroundColor Cyan
    Write-Host "- Interval: $Interval seconds" -ForegroundColor Cyan
    Write-Host "- Key to press: $KeyToPress" -ForegroundColor Cyan
    Write-Host "- Toast notifications: $(if(-not $DisableToast){'Enabled'}else{'Disabled'})" -ForegroundColor Cyan
    
    if (-not $script:burntToastAvailable -and -not $DisableToast) {
        Write-Host "Warning: BurntToast module not available. Toast notifications will not work." -ForegroundColor Yellow
        Write-Host "To install BurntToast, run: Install-Module -Name BurntToast -Scope CurrentUser" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

#endregion Helper Functions

#region Main Script

# Initialize BurntToast support
$script:burntToastAvailable = Initialize-BurntToastSupport

# Display configuration information
Show-ConfigurationInfo

# Main processing loop
try {
    while ($script:isRunning) {
        try {
            # Get the key code from the dictionary
            $keyCode = $script:virtualKeyCodes[$KeyToPress]
            
            # Simulate key press
            Invoke-KeyPress -KeyCode $keyCode
            
            # Clear screen and show status
            Clear-Host
            Show-StatusInformation
            Show-BatteryStatus
            
            # Wait for the interval, checking for quit key every 100ms
            $startTime = Get-Date
            $endTime = $startTime.AddSeconds($Interval)
            
            while ((Get-Date) -lt $endTime -and $script:isRunning) {
                Start-Sleep -Milliseconds 100
                if (Test-QuitKeyPressed) {
                    Write-Host "`nExiting LockBlocker..." -ForegroundColor Cyan
                    $script:isRunning = $false
                    break
                }
            }
        }
        catch {
            Write-Host "Error during execution: $($_.Exception.Message)" -ForegroundColor Red
            Start-Sleep -Seconds 5
        }
    }
}
finally {
    Write-Host "`nLockBlocker has been stopped." -ForegroundColor Cyan
    if ($script:burntToastAvailable) {
        try {
            New-BurntToastNotification -Text "LockBlocker", "LockBlocker has been stopped." -ErrorAction SilentlyContinue
        }
        catch {
            # Silently continue if final notification fails
        }
    }
}

#endregion Main Script