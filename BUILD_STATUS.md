# Pinocchio Windows Wheel Build Status

## Goal
Build a self-contained, portable Python wheel (`.whl`) for Pinocchio on Windows (x64) that includes all necessary DLL dependencies (EigenPy, URDFDOM, Boost, etc.) and works with Python 3.10 (specifically targeting NVIDIA Omniverse Kit).

## Current Progress

### 1. Build Environment Setup (`build_wheel_windows.ps1`)
- **Script**: Created a PowerShell script to automate the build.
- **Dependencies**: Uses `vcpkg` to install C++ dependencies.
- **Triplet Change**: Switched from `x64-windows-static-md-release` to `x64-windows` (dynamic linking) to ensure proper handling of Boost.Python and DLL distribution.

### 2. Fixed NumPy Import Issue
- **Problem**: The `_import_array` and `_import_umath` helpers were hidden/undefined due to precompiled header (PCH) conflicts with `NO_IMPORT_ARRAY`.
- **Solution**: Modified `bindings/python/numpy_import.cpp` to manually load the NumPy capsules (`numpy._core._multiarray_umath`) and populate the API tables, bypassing the PCH conflicts.

### 3. Fixed Wheel Layout
- **Problem**: `scikit-build-core` was installing artifacts into `dist/pinocchio-3.2.0.../pinocchio/lib/python3.10/site-packages/pinocchio`, creating a nested, unimportable structure.
- **Solution**: Updated `bindings/python/CMakeLists.txt` to detect `SKBUILD_PLATLIB_DIR` and install Python bindings directly to the package root (`pinocchio/`).

### 4. Fixed DLL Dependency Loading
- **Problem**: `ImportError: DLL load failed` because dependent DLLs (EigenPy, URDFDOM, Boost) were missing from the wheel or not found by the Windows loader.
- **Solution A (Loader)**: Updated `bindings/python/pinocchio/windows_dll_manager.py` to explicitly add `pinocchio/bin` to the DLL search path.
- **Solution B (Packaging)**: Updated `bindings/python/CMakeLists.txt` to automatically find and copy referenced DLLs (from vcpkg targets) into `pinocchio/bin` during the install step.

### 5. Fixed Boost.Python Debug Build Failure
- **Problem**: `boost-python` debug build failed because `python310_d.lib` was missing (likely a vcpkg port issue where debug libraries are not exposed correctly).
- **Solution**: Created and switched to `triplets/x64-windows-release.cmake` (dynamic linking, release only). This avoids the debug build issues and significantly speeds up dependency installation.

### 6. Fixed Missing DLLs in Wheel
- **Problem**: The generated wheel was missing dependent DLLs (Boost, EigenPy, URDFDOM) and Pinocchio's own DLLs (`pinocchio_default.dll` etc.) because the previous `CMakeLists.txt` logic failed to locate the imported targets' DLL paths.
- **Solution**: Updated `bindings/python/CMakeLists.txt` to:
    1. Explicitly install `pinocchio_default`, `pinocchio_parsers`, etc. targets to `bin/`.
    2. Use a `file(GLOB_RECURSE ...)` strategy to brute-force find and copy all DLLs from the `vcpkg_installed` directory into the wheel's `bin/` folder.

### 7. Fixed "DLL load failed: initialization routine failed"
- **Problem**: `ImportError: DLL load failed while importing pinocchio_pywrap_default: A dynamic link library (DLL) initialization routine failed.` This was caused by `numpy_import.cpp` using a **static global initializer** to load the NumPy C-API (`_multiarray_umath`). Static initializers in DLLs run during `LoadLibrary`, before the Python interpreter is fully aware of the module or before the GIL is held correctly for certain operations, leading to a crash or failure.
- **Solution**: Moved the NumPy initialization logic from a static global variable to a function `pinocchio_numpy_init()` and called it explicitly inside the `BOOST_PYTHON_MODULE` block in `bindings/python/module.cpp`. This ensures initialization happens at module import time, when the Python environment is stable.

## Current Status
**SUCCESS!** The wheel builds correctly, includes all DLLs, and imports successfully in a fresh environment.

## Key Files Modified
- `build_wheel_windows.ps1`: Main build orchestrator.
- `bindings/python/CMakeLists.txt`: Installation rules for copying DLLs.
- `bindings/python/numpy_import.cpp`: Custom NumPy initialization (moved to function).
- `bindings/python/module.cpp`: Called initialization function from module entry point.
- `bindings/python/pinocchio/windows_dll_manager.py`: DLL path helper.
