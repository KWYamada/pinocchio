#!/usr/bin/env pwsh
# ============================================================================
# Pinocchio Windows Wheel Build Script
# ============================================================================
# This script builds a portable .whl file for Pinocchio on Windows
# Compatible with CPython 3.10 and NVIDIA Omniverse Kit 106.x
# ============================================================================

param(
    [string]$VcpkgRoot = "$env:VCPKG_ROOT",
    [string]$BoostRoot = "",
    [string]$EigenRoot = "",
    [switch]$CleanBuild = $false,
    [switch]$UseVcpkg = $true,
    [switch]$SkipTests = $true
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Pinocchio Windows Wheel Builder" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

# ============================================================================
# Helper Functions
# ============================================================================

function Test-Command {
    param([string]$Command)
    try {
        if (Get-Command $Command -ErrorAction Stop) {
            return $true
        }
    } catch {
        return $false
    }
}

function Write-Step {
    param([string]$Message)
    Write-Host "`n>>> $Message" -ForegroundColor Green
}

function Write-Error-Exit {
    param([string]$Message)
    Write-Host "ERROR: $Message" -ForegroundColor Red
    exit 1
}

# ============================================================================
# Check Prerequisites
# ============================================================================

Write-Step "Checking prerequisites..."

# Check Python
if (-not (Test-Command "python")) {
    Write-Error-Exit "Python not found. Please install Python 3.10."
}

$pythonVersion = python --version 2>&1
Write-Host "Found: $pythonVersion"

if ($pythonVersion -notmatch "3\.10") {
    Write-Host "WARNING: Python 3.10 is recommended for Omniverse compatibility." -ForegroundColor Yellow
}

# Check CMake
if (-not (Test-Command "cmake")) {
    Write-Error-Exit "CMake not found. Please install CMake 3.22 or newer."
}

$cmakeVersion = cmake --version | Select-Object -First 1
Write-Host "Found: $cmakeVersion"

# Check Visual Studio / MSVC
if (-not (Test-Command "cl")) {
    Write-Host "MSVC compiler not found in PATH." -ForegroundColor Yellow
    Write-Host "Attempting to locate Visual Studio..." -ForegroundColor Yellow
    
    $vswhere = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
    if (Test-Path $vswhere) {
        $vsPath = & $vswhere -latest -property installationPath
        if ($vsPath) {
            $vcvarsall = Join-Path $vsPath "VC\Auxiliary\Build\vcvarsall.bat"
            if (Test-Path $vcvarsall) {
                Write-Host "Found Visual Studio at: $vsPath"
                Write-Host "Please run this script from a 'Developer Command Prompt' or 'x64 Native Tools Command Prompt'"
                Write-Host "Or run: `"$vcvarsall`" x64" -ForegroundColor Yellow
                exit 1
            }
        }
    }
    Write-Error-Exit "Visual Studio not found. Please install Visual Studio with C++ support."
}

# Check MSVC compiler (cl outputs to stderr, so we suppress the error)
try {
    $clOutput = & cl 2>&1 | Select-Object -First 1
    Write-Host "Found: MSVC compiler ($clOutput)"
} catch {
    Write-Host "Found: MSVC compiler (version check failed but compiler is present)"
}

# ============================================================================
# Setup Python Virtual Environment
# ============================================================================

Write-Step "Setting up Python virtual environment..."

$venvPath = ".\venv_build"

if ($CleanBuild -and (Test-Path $venvPath)) {
    Write-Host "Removing existing virtual environment..."
    Remove-Item -Recurse -Force $venvPath
}

if (-not (Test-Path $venvPath)) {
    python -m venv $venvPath
}

# Activate virtual environment
$activateScript = Join-Path $venvPath "Scripts\Activate.ps1"
if (Test-Path $activateScript) {
    & $activateScript
} else {
    Write-Error-Exit "Failed to create virtual environment"
}

Write-Host "Virtual environment activated: $venvPath"

# ============================================================================
# Install Python Dependencies
# ============================================================================

Write-Step "Installing Python build dependencies..."

python -m pip install --upgrade pip setuptools wheel
python -m pip install --upgrade "numpy==2.2.0"  # NumPy 2.x with modern ABI
python -m pip install --upgrade "scikit-build-core>=0.8.0"
python -m pip install --upgrade "pybind11>=2.11.0"
python -m pip install --upgrade build

Write-Host "Installed packages:"
python -m pip list | Select-String -Pattern "(numpy|scikit-build|pybind11)"

Write-Host "`nNote: Building with NumPy 2.2.0" -ForegroundColor Cyan
Write-Host "The wheel will require NumPy >=2.0.0 at runtime" -ForegroundColor Cyan

# ============================================================================
# Setup Dependencies (Boost, Eigen, etc.)
# ============================================================================

Write-Step "Setting up C++ dependencies..."

if ($UseVcpkg) {
    if ([string]::IsNullOrEmpty($VcpkgRoot)) {
        Write-Host "VCPKG_ROOT not set. Checking common locations..." -ForegroundColor Yellow
        $commonPaths = @(
            "C:\vcpkg",
            "C:\tools\vcpkg",
            "$env:USERPROFILE\vcpkg"
        )
        foreach ($path in $commonPaths) {
            if (Test-Path "$path\vcpkg.exe") {
                $VcpkgRoot = $path
                Write-Host "Found vcpkg at: $VcpkgRoot"
                break
            }
        }
    }
    
    if ([string]::IsNullOrEmpty($VcpkgRoot) -or -not (Test-Path "$VcpkgRoot\vcpkg.exe")) {
        Write-Host "vcpkg not found. Installing dependencies is required." -ForegroundColor Yellow
        Write-Host @"

Please install vcpkg:
  1. git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg
  2. cd C:\vcpkg
  3. .\bootstrap-vcpkg.bat
  4. Set environment variable: `$env:VCPKG_ROOT = 'C:\vcpkg'

Or provide paths manually:
  -BoostRoot 'C:\path\to\boost'
  -EigenRoot 'C:\path\to\eigen'
"@ -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "Using vcpkg at: $VcpkgRoot"
    $env:VCPKG_ROOT = $VcpkgRoot
    
    Write-Step "Installing dependencies via vcpkg..."
    
    # Use x64-windows-release: dynamic libs (DLLs) release only to avoid debug lib issues and speed up build
    $vcpkgTriplet = "x64-windows-release"
    Write-Host "Installing packages from vcpkg.json with triplet: $vcpkgTriplet"
    
    # In manifest mode, vcpkg reads from vcpkg.json automatically
    # Just run vcpkg install without package arguments
    Push-Location $PSScriptRoot
    & "$VcpkgRoot\vcpkg.exe" install --triplet $vcpkgTriplet --overlay-ports=./ports --overlay-triplets=./triplets
    $vcpkgExitCode = $LASTEXITCODE
    Pop-Location
    
    if ($vcpkgExitCode -ne 0) {
        Write-Error-Exit "Failed to install vcpkg dependencies from vcpkg.json"
    }
    
    Write-Host "Dependencies installed successfully" -ForegroundColor Green
    
    # Set CMake toolchain
    $env:CMAKE_TOOLCHAIN_FILE = "$VcpkgRoot\scripts\buildsystems\vcpkg.cmake"
    $env:VCPKG_TARGET_TRIPLET = $vcpkgTriplet
    Write-Host "CMAKE_TOOLCHAIN_FILE set to: $env:CMAKE_TOOLCHAIN_FILE"
    Write-Host "VCPKG_TARGET_TRIPLET set to: $env:VCPKG_TARGET_TRIPLET"
} else {
    Write-Host "Manual dependency paths:"
    if (-not [string]::IsNullOrEmpty($BoostRoot)) {
        $env:BOOST_ROOT = $BoostRoot
        Write-Host "  BOOST_ROOT = $BoostRoot"
    }
    if (-not [string]::IsNullOrEmpty($EigenRoot)) {
        $env:EIGEN3_INCLUDE_DIR = "$EigenRoot"
        Write-Host "  EIGEN3_INCLUDE_DIR = $EigenRoot"
    }
}

# ============================================================================
# Clean Build Directory
# ============================================================================

if ($CleanBuild) {
    Write-Step "Cleaning build directories..."
    
    $dirsToClean = @("build", "dist", "_skbuild", "pinocchio.egg-info")
    foreach ($dir in $dirsToClean) {
        if (Test-Path $dir) {
            Write-Host "Removing $dir..."
            Remove-Item -Recurse -Force $dir
        }
    }
}

# ============================================================================
# Build Wheel
# ============================================================================

Write-Step "Building wheel..."

$buildArgs = @(
    "-m", "build",
    "--wheel",
    "--no-isolation"
)

if ($env:CMAKE_TOOLCHAIN_FILE) {
    # Use wrapper toolchain that blocks pkg-config to prevent vcpkg recursion
    $wrapperToolchain = "$PSScriptRoot/cmake/VcpkgToolchainWrapper.cmake" -replace '\\', '/'
    # Set VCPKG_ROOT for the wrapper to find vcpkg
    $tripletsPath = "$PSScriptRoot/triplets" -replace '\\', '/'
    $jrlModulesDir = Join-Path $PSScriptRoot "vcpkg_installed\$($env:VCPKG_TARGET_TRIPLET)\share\jrl-cmakemodules"
    if (-not (Test-Path $jrlModulesDir)) {
        $jrlModulesDir = "$PSScriptRoot/cmake"
    }
    $jrlModulesDir = $jrlModulesDir -replace '\\', '/'
    $cmakeArgs = @(
        "-DCMAKE_TOOLCHAIN_FILE=`"$wrapperToolchain`"",
        "-DVCPKG_TARGET_TRIPLET=$env:VCPKG_TARGET_TRIPLET",
        "-DVCPKG_OVERLAY_TRIPLETS=`"$tripletsPath`"",
        "-Djrl-cmakemodules_DIR=`"$jrlModulesDir`""
    )
    $env:CMAKE_ARGS = $cmakeArgs -join ' '
    Write-Host "CMAKE_ARGS: $env:CMAKE_ARGS"
    Write-Host "Using vcpkg wrapper toolchain to prevent pkg-config recursion"
}

Write-Host "Building with command: python $($buildArgs -join ' ')"
python @buildArgs

if ($LASTEXITCODE -ne 0) {
    Write-Error-Exit "Wheel build failed"
}

# ============================================================================
# Verify Wheel
# ============================================================================

Write-Step "Verifying wheel..."

if (-not (Test-Path "dist")) {
    Write-Error-Exit "dist directory not found"
}

$wheels = Get-ChildItem -Path "dist" -Filter "*.whl"
if ($wheels.Count -eq 0) {
    Write-Error-Exit "No wheel file generated"
}

Write-Host "`nGenerated wheel(s):" -ForegroundColor Green
foreach ($wheel in $wheels) {
    Write-Host "  $($wheel.Name)" -ForegroundColor Cyan
    Write-Host "  Size: $([math]::Round($wheel.Length / 1MB, 2)) MB"
    Write-Host "  Path: $($wheel.FullName)"
}

# Check wheel contents
Write-Step "Inspecting wheel contents..."
$wheel = $wheels[0]
python -m zipfile -l $wheel.FullName | Select-String -Pattern "\.pyd|\.dll|\.py" | Select-Object -First 20
Write-Host "... (use 'python -m zipfile -l <wheel>' to see full contents)"

# ============================================================================
# Optional: Test Installation
# ============================================================================

if (-not $SkipTests) {
    Write-Step "Testing wheel installation..."
    
    $testVenv = ".\venv_test"
    if (Test-Path $testVenv) {
        Remove-Item -Recurse -Force $testVenv
    }
    
    python -m venv $testVenv
    & "$testVenv\Scripts\Activate.ps1"
    
    python -m pip install --upgrade pip
    python -m pip install numpy==1.26.4
    python -m pip install $wheel.FullName
    
    Write-Host "Testing import..."
    $testResult = python -c "import pinocchio; print(f'Pinocchio version: {pinocchio.__version__}'); print('Import successful!')" 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host $testResult -ForegroundColor Green
    } else {
        Write-Host "Import test failed:" -ForegroundColor Red
        Write-Host $testResult
    }
    
    # Deactivate test venv
    deactivate
    
    # Reactivate build venv
    & $activateScript
}

# ============================================================================
# Summary
# ============================================================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Wheel location: dist\$($wheels[0].Name)"
Write-Host "`nTo install in your environment:"
Write-Host "  pip install dist\$($wheels[0].Name)" -ForegroundColor Yellow
Write-Host "`nTo test in Omniverse Kit:"
Write-Host "  1. Copy wheel to your Omniverse project"
Write-Host "  2. From Kit Python console: pip install <path-to-wheel>"
Write-Host "  3. Test: import pinocchio"
Write-Host "========================================" -ForegroundColor Cyan


