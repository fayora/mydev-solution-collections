# This script is used to provision the Loome Assist resources on a Windows VM
# It runs once when the VM is started for the first time, and it is not intended to be run again

param (
    [string]$jsonConfig
)

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

# Specify the scripts directory and create it if it doesn't exist
# ====================================================================================
$LoomeScriptsDir ="C:\ProgramData\LoomeAssist"
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

# Startup Script: Creates a script to run the other scripts each time the VM starts up
# ====================================================================================
$StartupFile ="C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\LoomeBootStrapScript.cmd"
$StartupScript ="
echo Run the mount script for all Loome repositories
Powershell.exe -WindowStyle Hidden -File $MountScriptPath `"$jsonConfig`"
"
# Pipe the contents of the startup script to the startup file
$StartupScript | Out-File -FilePath $StartupFile -Encoding ascii
