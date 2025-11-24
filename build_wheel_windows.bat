@echo off
REM ============================================================================
REM Pinocchio Windows Wheel Build Script (Batch Version)
REM ============================================================================
REM This is a simpler CMD alternative to build_wheel_windows.ps1
REM For full features, use the PowerShell version
REM ============================================================================

setlocal enabledelayedexpansion

echo ========================================
echo Pinocchio Windows Wheel Builder
echo ========================================
echo.

REM Check Python
where python >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Python not found in PATH
    exit /b 1
)

python --version
echo.

REM Check CMake
where cmake >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: CMake not found in PATH
    exit /b 1
)

cmake --version
echo.

REM Check MSVC
where cl >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: MSVC compiler not found
    echo Please run this script from "x64 Native Tools Command Prompt for VS"
    exit /b 1
)

cl 2>&1 | findstr /C:"Compiler"
echo.

REM Setup Python virtual environment
echo Setting up Python environment...
if not exist "venv_build" (
    python -m venv venv_build
)

call venv_build\Scripts\activate.bat

echo Installing Python dependencies...
python -m pip install --upgrade pip setuptools wheel
python -m pip install --upgrade "numpy==2.2.0"
python -m pip install --upgrade "scikit-build-core>=0.8.0"
python -m pip install --upgrade "pybind11>=2.11.0"
python -m pip install --upgrade build

echo.
echo Python packages installed:
python -m pip list | findstr /I "numpy scikit pybind"
echo.

REM Check for vcpkg
if "%VCPKG_ROOT%"=="" (
    if exist "C:\vcpkg\vcpkg.exe" (
        set "VCPKG_ROOT=C:\vcpkg"
        echo Found vcpkg at C:\vcpkg
    ) else (
        echo WARNING: VCPKG_ROOT not set and vcpkg not found at C:\vcpkg
        echo.
        echo Please either:
        echo   1. Install vcpkg and set VCPKG_ROOT environment variable
        echo   2. Set BOOST_ROOT and EIGEN3_INCLUDE_DIR manually
        echo.
        echo To install vcpkg:
        echo   git clone https://github.com/Microsoft/vcpkg.git C:\vcpkg
        echo   cd C:\vcpkg
        echo   bootstrap-vcpkg.bat
        echo.
        pause
        exit /b 1
    )
)

echo Using vcpkg at: %VCPKG_ROOT%
echo.

REM Install dependencies via vcpkg
echo Installing C++ dependencies...
set "VCPKG_TRIPLET=x64-windows-static"

"%VCPKG_ROOT%\vcpkg.exe" install boost-filesystem:%VCPKG_TRIPLET%
"%VCPKG_ROOT%\vcpkg.exe" install boost-serialization:%VCPKG_TRIPLET%
"%VCPKG_ROOT%\vcpkg.exe" install eigen3:%VCPKG_TRIPLET%
"%VCPKG_ROOT%\vcpkg.exe" install urdfdom:%VCPKG_TRIPLET%

echo.
echo Dependencies installed successfully
echo.

REM Set CMake variables
set "CMAKE_TOOLCHAIN_FILE=%VCPKG_ROOT%\scripts\buildsystems\vcpkg.cmake"
set "CMAKE_ARGS=-DCMAKE_TOOLCHAIN_FILE=%CMAKE_TOOLCHAIN_FILE% -DVCPKG_TARGET_TRIPLET=%VCPKG_TRIPLET%"

echo CMake configuration:
echo   CMAKE_TOOLCHAIN_FILE=%CMAKE_TOOLCHAIN_FILE%
echo   VCPKG_TARGET_TRIPLET=%VCPKG_TRIPLET%
echo.

REM Build wheel
echo Building wheel...
python -m build --wheel --no-isolation

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Wheel build failed
    exit /b 1
)

echo.
echo ========================================
echo Build Complete!
echo ========================================
echo.

if exist "dist\" (
    echo Generated wheel:
    dir /b dist\*.whl
    echo.
    echo Wheel location: dist\
    echo.
    echo To install:
    echo   pip install dist\pinocchio-*.whl
    echo.
    echo To test:
    echo   python -c "import pinocchio; print(pinocchio.__version__)"
) else (
    echo ERROR: dist\ directory not found
    exit /b 1
)

echo ========================================
endlocal


