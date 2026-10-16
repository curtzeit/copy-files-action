param (
    [Parameter(Mandatory = $true)][string]$Server,
    [Parameter(Mandatory = $true)][string]$Username,
    [Parameter(Mandatory = $true)][string]$Password,
    [Parameter(Mandatory = $true)][string]$ProjectName,
    [Parameter(Mandatory = $true)][string]$TargetPath,
    [Parameter(Mandatory = $true)][string]$StagingPath,
    [string]$BackupPath = $null
)

# Any error anywhere in this script must fail the build. Without this, cmdlet
# failures only write to the error stream and the script still exits 0.
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$session = $null

try {
    # Use StagingPath as BackupPath if BackupPath is null or empty
    if ([string]::IsNullOrWhiteSpace($BackupPath)) {
        $BackupPath = $StagingPath
    }

    $zipFile = "$ProjectName.zip"
    $localZip = Join-Path (Get-Location).Path $zipFile
    if (-not (Test-Path -LiteralPath $localZip -PathType Leaf)) {
        throw "Build artifact '$zipFile' was not found in $((Get-Location).Path). Zip the build output to '$zipFile' before this step."
    }

    Write-Host "Connecting to $Server as $Username..."
    $so = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
    $securePassword = ConvertTo-SecureString $Password -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential($Username, $securePassword)
    $session = New-PSSession -ComputerName $Server -SessionOption $so -Credential $credential

    $remoteZip = [System.IO.Path]::Combine($StagingPath, $zipFile)
    $backupZip = [System.IO.Path]::Combine($BackupPath, "$ProjectName.Backup.zip")

    # Fail early with a clear message rather than part-way through the deployment
    Invoke-Command -Session $session -ScriptBlock {
        param ($stagingPath, $backupPath, $targetPath)
        $ErrorActionPreference = 'Stop'

        foreach ($path in @($stagingPath, $backupPath, $targetPath)) {
            if (-not (Test-Path -LiteralPath $path -PathType Container)) {
                throw "Remote folder does not exist: $path"
            }
        }
    } -ArgumentList $StagingPath, $BackupPath, $TargetPath

    # Remove existing prod deployment zip in staging folder
    Invoke-Command -Session $session -ScriptBlock {
        param ($remoteZip)
        $ErrorActionPreference = 'Stop'

        if (Test-Path -LiteralPath $remoteZip) {
            Remove-Item -LiteralPath $remoteZip -Force
        }
    } -ArgumentList $remoteZip

    # Copy the new file to the remote session
    Write-Host "Copying $zipFile to $remoteZip..."
    Copy-Item -LiteralPath $localZip -Destination $remoteZip -ToSession $session

    Invoke-Command -Session $session -ScriptBlock {
        param ($remoteZip, $backupZip, $targetPath)
        $ErrorActionPreference = 'Stop'
        $ProgressPreference = 'SilentlyContinue'

        if (-not (Test-Path -LiteralPath $remoteZip -PathType Leaf)) {
            throw "Deployment zip did not arrive on the server at $remoteZip"
        }

        # Remove old backup zip if exists
        if (Test-Path -LiteralPath $backupZip) {
            Remove-Item -LiteralPath $backupZip -Force
        }

        # Create zip of current deployed code and put in backup folder
        if (Get-ChildItem -LiteralPath $targetPath -Force) {
            Compress-Archive -Path (Join-Path $targetPath '*') -DestinationPath $backupZip
            if (-not (Test-Path -LiteralPath $backupZip -PathType Leaf)) {
                throw "Backup archive was not created at $backupZip. Aborting before the live deployment is touched."
            }
            Write-Host "Backed up current deployment to $backupZip"
        }
        else {
            Write-Host "$targetPath is empty, nothing to back up."
        }

        # Remove all files from current prod location. Enumerate the top level only;
        # Remove-Item -Recurse clears what is underneath each entry.
        Get-ChildItem -LiteralPath $targetPath -Force | Remove-Item -Recurse -Force

        $leftovers = @(Get-ChildItem -LiteralPath $targetPath -Force)
        if ($leftovers.Count -gt 0) {
            throw "Could not clear $targetPath. Still present (file in use?): $($leftovers.Name -join ', ')"
        }

        # Extract all files from new deployment zip to production folder
        Expand-Archive -LiteralPath $remoteZip -DestinationPath $targetPath -Force

        $deployed = @(Get-ChildItem -LiteralPath $targetPath -Recurse -Force -File)
        if ($deployed.Count -eq 0) {
            throw "Extraction of $remoteZip left $targetPath empty."
        }

        Write-Host "Deployed $($deployed.Count) file(s) to $targetPath"
    } -ArgumentList $remoteZip, $backupZip, $TargetPath

    Write-Host "Deployment of $ProjectName to $Server completed successfully."
    exit 0
}
catch {
    Write-Host "::error::Deployment of $ProjectName to $Server failed: $($_.Exception.Message)"
    if ($_.ScriptStackTrace) {
        Write-Host $_.ScriptStackTrace
    }
    exit 1
}
finally {
    if ($session) {
        Remove-PSSession -Session $session -ErrorAction SilentlyContinue
    }
}
