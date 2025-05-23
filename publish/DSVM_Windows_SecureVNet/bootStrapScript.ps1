# This script is used to provision the Loome Assist resources on a Windows VM
# It runs once when the VM is started for the first time, and it is not intended to be run again

param (
    [string]$jsonConfig
)

# Start a timer to measure script execution time
$startTime = Get-Date

# Write the output to a log file
# ====================================================================================
# Ensure the directory exists in the ProgramData folder
$logDir = Join-Path -Path $Env:ProgramData -ChildPath "Loome"
if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
# Define the log file path
$logFile = Join-Path -Path $logDir -ChildPath "bootStrapScript.log"
# Redirect all output to the log file
$null = Start-Transcript -Path $logFile -Append -NoClobber

# Write the start time to the log file
Write-Host "Script started at: $startTime"

# Specify the scripts directory and create it if it doesn't exist
# ====================================================================================
$LoomeScriptsDir = Join-Path -Path $Env:ProgramData -ChildPath "Loome"
if (!(Test-Path $LoomeScriptsDir)) {
    New-Item -ItemType Directory -Path $LoomeScriptsDir -Force | Out-Null
}

# Script 1: Mount Loome repositories
# ====================================================================================
# Specify the script and copy it to the Loome Scripts directory
$MountScript = "mountRepos.ps1"
$MountScriptPath = Join-Path -Path $LoomeScriptsDir -ChildPath $MountScript
# Copy the mount script to the directory
Copy-Item -Path $PSScriptRoot\$MountScript -Destination $MountScriptPath -Force
# Convert the JSON string to base64 for passing to the script
$jsonConfigBase64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($jsonConfig))
# Create the command to run the mount script with the JSON string as an argument
$MountScriptCommand = "Powershell.exe -WindowStyle Hidden -File $MountScriptPath `"$jsonConfigBase64`""

# Startup Script: Creates a script to run the other scripts each time the VM starts up
# ====================================================================================
$StartupFile ="C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\LoomeBootStrapScript.cmd"
$StartupScript ="
echo Run the mount script for all Loome repositories
$MountScriptCommand
"
# Pipe the contents of the startup script to the startup file
$StartupScript | Out-File -FilePath $StartupFile -Encoding ascii

Write-Host "Bootstrap script completed."
# Calculate and display the total execution time
$endTime = Get-Date
$executionTime = $endTime - $startTime
Write-Host "Script completed at: $endTime"
Write-Host "Total execution time: $($executionTime.TotalSeconds) seconds"
Write-Host "=========================================="
# Stop the transcript
Stop-Transcript
