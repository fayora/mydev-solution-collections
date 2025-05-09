# Script to mount Azure File Shares from a JSON file
# It accepts a JSON string with the following structure:
# {
#     "DataRepositories": [
#         {
#             "StorageAccountName": "account1",
#             "StorageAccountKey": "key1==",
#             "FileshareName": "fileshare1"
#         },
#         {
#             "StorageAccountName": "account2",
#             "StorageAccountKey": "key2==",
#             "FileshareName": "fileshare2"
#         }
#     ]
# }

# Parameter to accept JSON string, passed from the command line
param (
    [string]$jsonConfig
)

# Write the output to a log file
# Ensure the directory exists in the ProgramData folder
$logDir = Join-Path -Path $Env:ProgramData -ChildPath "Loome"
if (-not (Test-Path -Path $logDir)) {
    New-Item -Path $logDir -ItemType Directory -Force | Out-Null
}
# Define the log file path
$logFile = Join-Path -Path $logDir -ChildPath "mountRepos.log"
# Redirect all output to the log file
$null = Start-Transcript -Path $logFile -Append -NoClobber

# Check if the JSON is provided
if (-not $jsonConfig) {
    Write-Host "ERROR: No JSON provided. Exiting."
    exit 1
}

# Output the JSON input for reference
Write-Host "----------------------------------------"
Write-Host "Input JSON:"
Write-Host "$jsonConfig"
Write-Host "----------------------------------------"
 
# Check if the JSON is valid
try {
    $jsonConfig | ConvertFrom-Json | Out-Null
} catch {
    Write-Host "ERROR: Invalid JSON. Exiting."
    exit 1
}

# Parse the JSON
$config = $jsonConfig | ConvertFrom-Json

# Available drive letters to use (excluding already used ones)
$driveLetters = @('K', 'L', 'M', 'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z')

# Get currently used drive letters
$usedDrives = (Get-PSDrive -PSProvider FileSystem).Name
$availableDriveLetters = $driveLetters | Where-Object { $usedDrives -notcontains $_ }

# Function to mount a file share
function Mount-AzureFileShare {
    param (
        [string]$StorageAccountName,
        [string]$StorageAccountKey,
        [string]$FileshareName,
        [string]$DriveLetter
    )
    
    Write-Host "Mounting $FileshareName from $StorageAccountName as drive $DriveLetter..."
    
    # Save the password so the drive will persist on reboot
    Write-Host "Storing credentials for $FileshareName using key $StorageAccountKey..."
    cmd.exe /C "cmdkey /add:`"$StorageAccountName.file.core.windows.net`" /user:`"localhost\$StorageAccountName`" /pass:`"$StorageAccountKey`""
    
    # Check if drive is already mounted
    $existingDrive = Get-PSDrive -Name $DriveLetter -ErrorAction SilentlyContinue
    if ($existingDrive) {
        Write-Host "WARNING: Drive $DriveLetter is already in use. Skipping..."
        return
    }
    
    # Mount the drive
    $rootPath = "\\$StorageAccountName.file.core.windows.net\$FileshareName"
    Write-Host "Mounting $rootPath as drive $DriveLetter..."
    try {
        New-PSDrive -Name $DriveLetter -PSProvider FileSystem -Root $rootPath -Persist -Scope Global
        Write-Host "Successfully mounted $FileshareName as drive $DriveLetter."
    }
    catch {
        Write-Host "ERROR: Failed to mount $FileshareName as drive $DriveLetter. Error: $_"
    }
}

# Main script execution
Write-Host "Starting to mount Azure file shares..."

$driveIndex = 0
foreach ($repo in $config) {
    # Check if we have available drive letters
    if ($driveIndex -ge $availableDriveLetters.Count) {
        Write-Host "ERROR: No more available drive letters to use!"
        break
    }
    
    $driveLetter = $availableDriveLetters[$driveIndex]
    Mount-AzureFileShare -StorageAccountName $repo.StorageAccountName `
                        -StorageAccountKey $repo.StorageAccountKey `
                        -FileshareName $repo.FileshareName `
                        -DriveLetter $driveLetter
    
    $driveIndex++
}

Write-Host "File share mounting process completed."
Stop-Transcript