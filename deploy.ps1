param (
    [string]$Server,
    [string]$Username,
    [string]$Password,
    [string]$ProjectName,
    [string]$TargetPath,
    [string]$StagingPath,
    [string]$BackupPath
)


# Use StagingPath as BackupPath if BackupPath is null or empty
if (-not $BackupPath) {
    $BackupPath = $StagingPath
}


$so = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
$securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
$credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)
$session = New-PSSession -ComputerName $Server -SessionOption $so -UseSSL -Credential $credential

$zipFile = "$ProjectName.zip"
$remoteZip = Join-Path $StagingPath $zipFile
$backupZip = Join-Path $BackupPath "$ProjectName.Backup.zip"

# Remove existing prod deployment zip in staging folder
Invoke-Command -Session $session -ScriptBlock {
    param($remoteZip)
    Remove-Item -Path $remoteZip -Force -ErrorAction SilentlyContinue
} -ArgumentList $remoteZip

# Copy the new file to the remote session
Copy-Item -Path ".\$zipFile" -Destination $remoteZip -ToSession $session

Invoke-Command -Session $session -ScriptBlock {
    param ($remoteZip, $backupZip, $targetPath)

    # Remove old backup zip if exists    
    Remove-Item -Path $backupZip -Force -ErrorAction SilentlyContinue

    # Create zip of current deployed code and put in backup folder
    Compress-Archive -Path $targetPath -DestinationPath $backupZip

    # Remove all files from current prod location
    Get-ChildItem -Path $targetPath -Recurse -Force | Remove-Item -Recurse -Force

    # Extract all files from new deployment zip to production folder
    Expand-Archive -Path $remoteZip -DestinationPath $targetPath -Force

} -ArgumentList $remoteZip, $backupZip, $TargetPath
