<#
.SYNOPSIS
    Validate WSL and Docker Desktop state before and after shrink operations.

.DESCRIPTION
    This script provides diagnostic information about your WSL2 and Docker Desktop
    environment. Run it before shrinking to understand current state, and after
    to verify the shrink was successful.

.EXAMPLE
    .\validate-wsl-state.ps1
    
.NOTES
    Author: Adnan Sattar
    Version: 1.0.0
#>

[CmdletBinding()]
param()

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 60) -ForegroundColor Cyan
    Write-Host " $Title" -ForegroundColor White
    Write-Host ("=" * 60) -ForegroundColor Cyan
}

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1TB) { return "{0:N2} TB" -f ($Bytes / 1TB) }
    if ($Bytes -ge 1GB) { return "{0:N2} GB" -f ($Bytes / 1GB) }
    if ($Bytes -ge 1MB) { return "{0:N2} MB" -f ($Bytes / 1MB) }
    if ($Bytes -ge 1KB) { return "{0:N2} KB" -f ($Bytes / 1KB) }
    return "$Bytes B"
}

# Banner
Write-Host @"

 __      __  _____  _        _____ _        _         
 \ \    / / / ____|| |      / ____| |      | |        
  \ \  / / | (___  | |     | (___ | |_ __ _| |_ ___   
   \ \/ /   \___ \ | |      \___ \| __/ _` | __/ _ \  
    \  /    ____) || |____  ____) | || (_| | ||  __/  
     \/    |_____/ |______||_____/ \__\__,_|\__\___|  
                                                      
              WSL2 Environment Validator v1.0.0

"@ -ForegroundColor Cyan

# ============================================================================
# SYSTEM INFORMATION
# ============================================================================

Write-Section "System Information"

$os = Get-CimInstance Win32_OperatingSystem
Write-Host "  OS:            $($os.Caption) ($($os.Version))"
Write-Host "  Architecture:  $($env:PROCESSOR_ARCHITECTURE)"

# ============================================================================
# WSL VERSION
# ============================================================================

Write-Section "WSL Version"

try {
    $wslVersion = wsl.exe --version 2>&1
    $wslVersion | ForEach-Object { Write-Host "  $_" }
}
catch {
    Write-Host "  WSL not available or error: $_" -ForegroundColor Red
}

# ============================================================================
# WSL DISTRIBUTIONS
# ============================================================================

Write-Section "WSL Distributions"

try {
    $distros = wsl.exe --list --verbose 2>&1
    if ($distros) {
        $distros | ForEach-Object { Write-Host "  $_" }
    }
    else {
        Write-Host "  No WSL distributions found" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "  Error listing distributions: $_" -ForegroundColor Red
}

# ============================================================================
# DOCKER VHDX FILES
# ============================================================================

Write-Section "Docker VHDX Files"

$searchPaths = @(
    "$env:LOCALAPPDATA\Docker\wsl\disk",
    "$env:LOCALAPPDATA\Docker\wsl\data",
    "$env:LOCALAPPDATA\Docker\wsl"
)

$vhdxFiles = @()

foreach ($path in $searchPaths) {
    if (Test-Path $path) {
        $files = Get-ChildItem -Path $path -Filter "*.vhdx" -Recurse -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $vhdxFiles += $file
        }
    }
}

if ($vhdxFiles.Count -eq 0) {
    Write-Host "  No VHDX files found in standard Docker locations" -ForegroundColor Yellow
}
else {
    $totalSize = 0
    foreach ($file in $vhdxFiles) {
        $size = $file.Length
        $totalSize += $size
        $sizeStr = Format-Size $size
        
        # Check sparse status
        $sparseStatus = "Unknown"
        try {
            $sparseOutput = fsutil.exe sparse queryflag $file.FullName 2>&1
            if ($sparseOutput -match "set as sparse") {
                $sparseStatus = "Yes"
            }
            else {
                $sparseStatus = "No"
            }
        }
        catch { }
        
        Write-Host ""
        Write-Host "  File:    $($file.Name)" -ForegroundColor White
        Write-Host "  Path:    $($file.FullName)" -ForegroundColor Gray
        Write-Host "  Size:    $sizeStr" -ForegroundColor $(if ($size -gt 50GB) { "Red" } elseif ($size -gt 20GB) { "Yellow" } else { "Green" })
        Write-Host "  Sparse:  $sparseStatus" -ForegroundColor $(if ($sparseStatus -eq "Yes") { "Green" } else { "Yellow" })
        Write-Host "  Modified: $($file.LastWriteTime)"
    }
    
    Write-Host ""
    Write-Host "  Total VHDX Size: $(Format-Size $totalSize)" -ForegroundColor $(if ($totalSize -gt 50GB) { "Red" } else { "Green" })
}

# ============================================================================
# DOCKER SERVICE STATUS
# ============================================================================

Write-Section "Docker Service Status"

$dockerService = Get-Service -Name "com.docker.service" -ErrorAction SilentlyContinue
if ($dockerService) {
    $statusColor = if ($dockerService.Status -eq "Running") { "Green" } else { "Yellow" }
    Write-Host "  Service Name:   com.docker.service"
    Write-Host "  Status:         $($dockerService.Status)" -ForegroundColor $statusColor
    Write-Host "  Start Type:     $($dockerService.StartType)"
}
else {
    Write-Host "  Docker service not found" -ForegroundColor Yellow
}

# Check for running Docker processes
Write-Host ""
Write-Host "  Docker Processes:" -ForegroundColor White
$dockerProcesses = Get-Process | Where-Object { $_.Name -like "*docker*" } | Select-Object Name, Id, @{N = 'Memory'; E = { Format-Size $_.WorkingSet64 } }
if ($dockerProcesses) {
    $dockerProcesses | ForEach-Object {
        Write-Host "    - $($_.Name) (PID: $($_.Id), Memory: $($_.Memory))"
    }
}
else {
    Write-Host "    No Docker processes running" -ForegroundColor Gray
}

# ============================================================================
# DOCKER SYSTEM INFO (if Docker is running)
# ============================================================================

Write-Section "Docker System Information"

try {
    $dockerInfo = docker info 2>&1
    if ($LASTEXITCODE -eq 0) {
        # Extract key info
        $serverVersion = ($dockerInfo | Where-Object { $_ -match "Server Version:" }) -replace ".*Server Version:\s*", ""
        $storageDriver = ($dockerInfo | Where-Object { $_ -match "Storage Driver:" }) -replace ".*Storage Driver:\s*", ""
        $rootDir = ($dockerInfo | Where-Object { $_ -match "Docker Root Dir:" }) -replace ".*Docker Root Dir:\s*", ""
        
        Write-Host "  Server Version:  $serverVersion"
        Write-Host "  Storage Driver:  $storageDriver"
        Write-Host "  Docker Root Dir: $rootDir"
        
        # Get disk usage
        Write-Host ""
        Write-Host "  Disk Usage:" -ForegroundColor White
        $diskUsage = docker system df 2>&1
        if ($LASTEXITCODE -eq 0) {
            $diskUsage | ForEach-Object { Write-Host "    $_" }
        }
    }
    else {
        Write-Host "  Docker daemon not running or not accessible" -ForegroundColor Yellow
        Write-Host "  (This is expected if you're in the middle of a shrink operation)" -ForegroundColor Gray
    }
}
catch {
    Write-Host "  Could not connect to Docker: $_" -ForegroundColor Yellow
}

# ============================================================================
# DISK SPACE
# ============================================================================

Write-Section "Disk Space"

$drives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Used -ne $null }
foreach ($drive in $drives) {
    $usedPercent = [math]::Round(($drive.Used / ($drive.Used + $drive.Free)) * 100, 1)
    $color = if ($usedPercent -gt 90) { "Red" } elseif ($usedPercent -gt 75) { "Yellow" } else { "Green" }
    
    Write-Host "  $($drive.Name): $(Format-Size $drive.Free) free / $(Format-Size ($drive.Used + $drive.Free)) total ($usedPercent% used)" -ForegroundColor $color
}

# ============================================================================
# RECOMMENDATIONS
# ============================================================================

Write-Section "Recommendations"

$recommendations = @()

# Check VHDX size
$maxVhdxSize = ($vhdxFiles | Measure-Object -Property Length -Maximum).Maximum
if ($maxVhdxSize -gt 50GB) {
    $recommendations += "VHDX file is over 50GB. Consider running the shrink script."
}

# Check sparse status
$nonSparseFiles = $vhdxFiles | Where-Object {
    $sparseOutput = fsutil.exe sparse queryflag $_.FullName 2>&1
    $sparseOutput -notmatch "set as sparse"
}
if ($nonSparseFiles.Count -gt 0) {
    $recommendations += "Some VHDX files are not sparse-enabled. Run: wsl --manage docker-desktop --set-sparse true --allow-unsafe"
}

# Check disk space
$systemDrive = Get-PSDrive -Name C -ErrorAction SilentlyContinue
if ($systemDrive -and ($systemDrive.Free / ($systemDrive.Used + $systemDrive.Free)) -lt 0.1) {
    $recommendations += "System drive is over 90% full. Consider cleaning up or moving Docker data."
}

if ($recommendations.Count -eq 0) {
    Write-Host "  No immediate issues detected." -ForegroundColor Green
}
else {
    foreach ($rec in $recommendations) {
        Write-Host "  - $rec" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host " Validation Complete" -ForegroundColor White
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host ""

