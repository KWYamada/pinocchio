#!/usr/bin/env pwsh
# ============================================================================
# Install NumPy in Omniverse Kit
# ============================================================================
# This script installs NumPy 1.26.4 in your Omniverse Kit Python environment
# ============================================================================

param(
    [string]$KitPath = "",
    [switch]$AutoDetect = $false
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Omniverse Kit NumPy Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================================
# Find Kit Python
# ============================================================================

function Find-KitPython {
    Write-Host "`nSearching for Omniverse Kit Python..." -ForegroundColor Yellow
    
    $searchPaths = @(
        # Current directory build
        ".\_build\windows-x86_64\release\kit\python.exe",
        ".\_build\windows-x86_64\release\python.exe",
        
        # Common Omniverse installation paths
        "$env:LOCALAPPDATA\ov\pkg\*\python.exe",
        "$env:LOCALAPPDATA\ov\pkg\*\kit\python.exe",
        "C:\Users\*\AppData\Local\ov\pkg\*\python.exe",
        
        # Kit SDK
        "C:\Users\*\AppData\Local\ov\pkg\kit-sdk-*\python.exe",
        "C:\Users\*\AppData\Local\ov\pkg\kit-*\python.exe"
    )
    
    foreach ($pattern in $searchPaths) {
        $found = Get-ChildItem -Path $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            return $found.FullName
        }
    }
    
    return $null
}

if ([string]::IsNullOrEmpty($KitPath)) {
    if ($AutoDetect) {
        $KitPath = Find-KitPython
        if ($KitPath) {
            Write-Host "Auto-detected Kit Python: $KitPath" -ForegroundColor Green
        }
    }
    
    if ([string]::IsNullOrEmpty($KitPath)) {
        Write-Host @"

Please provide the path to your Omniverse Kit Python executable.

Common locations:
  1. Kit App build: .\<app>\_build\windows-x86_64\release\kit\python.exe
  2. Kit SDK: C:\Users\<user>\AppData\Local\ov\pkg\kit-sdk-<version>\python.exe
  3. Isaac Sim: C:\Users\<user>\AppData\Local\ov\pkg\isaac-sim-<version>\python.exe

To find it:
  - Open Omniverse Kit app
  - Run in Python console: import sys; print(sys.executable)

Usage:
  .\install_numpy_omniverse.ps1 -KitPath "C:\path\to\kit\python.exe"
  .\install_numpy_omniverse.ps1 -AutoDetect

"@ -ForegroundColor Yellow
        exit 1
    }
}

# Normalize path
$KitPath = $KitPath -replace '\\kit\\kit\.exe$', '\kit\python.exe'
$KitPath = $KitPath -replace '\\python\\python\.exe$', '\python.exe'

if (-not (Test-Path $KitPath)) {
    Write-Host "ERROR: Python executable not found at: $KitPath" -ForegroundColor Red
    exit 1
}

Write-Host "`nUsing Kit Python: $KitPath" -ForegroundColor Green

# ============================================================================
# Check Current Environment
# ============================================================================

Write-Host "`nChecking Python environment..." -ForegroundColor Cyan

$pythonVersion = & $KitPath --version 2>&1
Write-Host "Python version: $pythonVersion"

if ($pythonVersion -notmatch "3\.10") {
    Write-Host "WARNING: Expected Python 3.10, found: $pythonVersion" -ForegroundColor Yellow
    Write-Host "The Pinocchio wheel may not be compatible." -ForegroundColor Yellow
    $continue = Read-Host "Continue anyway? (y/n)"
    if ($continue -ne "y") {
        exit 0
    }
}

# Check if numpy is already installed
Write-Host "`nChecking for existing NumPy installation..."
$numpyCheck = & $KitPath -c "import numpy; print(numpy.__version__)" 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "NumPy is already installed: $numpyCheck" -ForegroundColor Green
    $upgrade = Read-Host "Upgrade to version 2.2.0? (y/n)"
    if ($upgrade -ne "y") {
        Write-Host "Keeping existing NumPy installation." -ForegroundColor Yellow
        exit 0
    }
} else {
    Write-Host "NumPy not found. Installing..." -ForegroundColor Yellow
}

# ============================================================================
# Install NumPy
# ============================================================================

Write-Host "`nInstalling NumPy 1.26.4..." -ForegroundColor Cyan

try {
    # First ensure pip is available
    Write-Host "Ensuring pip is available..."
    & $KitPath -m pip --version
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "pip not available, installing..." -ForegroundColor Yellow
        & $KitPath -m ensurepip --default-pip
    }
    
    # Upgrade pip
    Write-Host "Upgrading pip..."
    & $KitPath -m pip install --upgrade pip
    
    # Install numpy 2.2.0
    Write-Host "Installing numpy 2.2.0..."
    & $KitPath -m pip install "numpy==2.2.0"
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to install NumPy"
    }
    
    # Verify installation
    Write-Host "`nVerifying installation..." -ForegroundColor Cyan
    $installedVersion = & $KitPath -c "import numpy; print(f'NumPy {numpy.__version__} installed at {numpy.__file__}')" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "`n✅ Success!" -ForegroundColor Green
        Write-Host $installedVersion
        
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "NumPy is now installed in Omniverse Kit!" -ForegroundColor Green
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "`nYou can now install Pinocchio:"
        Write-Host "  & `"$KitPath`" -m pip install dist\pinocchio-*.whl" -ForegroundColor Yellow
        Write-Host "`nOr test directly:"
        Write-Host "  & `"$KitPath`" -c `"import numpy; print(numpy.__version__)`"" -ForegroundColor Yellow
        
    } else {
        throw "Installation verification failed"
    }
    
} catch {
    Write-Host "`n❌ Installation failed: $_" -ForegroundColor Red
    Write-Host "`nTroubleshooting:" -ForegroundColor Yellow
    Write-Host "1. Make sure Kit is not running"
    Write-Host "2. Run this script as Administrator if needed"
    Write-Host "3. Check Kit's Python environment permissions"
    Write-Host "4. Try manual installation:"
    Write-Host "   & `"$KitPath`" -m pip install numpy==1.26.4" -ForegroundColor Cyan
    exit 1
}

