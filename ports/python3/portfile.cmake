set(PYTHON_ROOT "C:/Users/chen7/AppData/Roaming/uv/python/cpython-3.10.15-windows-x86_64-none")

message(STATUS "Using local Python 3.10 from: ${PYTHON_ROOT}")

# Headers
file(INSTALL "${PYTHON_ROOT}/include/" DESTINATION "${CURRENT_PACKAGES_DIR}/include/python3.10")
# CMake FindPython usually looks for pythonX.Y/Python.h or just Python.h
# Let's copy to include/python3.10 and include/ to be safe, or just include/
# Official port uses include/python3.X/
# Let's stick to include/python3.10/ and create a symlink or copy if needed.
# Actually, FindPython looks in include/python3.10 automatically if version matches.

# Libs
file(INSTALL "${PYTHON_ROOT}/libs/python310.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")
file(INSTALL "${PYTHON_ROOT}/libs/python3.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/lib")

file(INSTALL "${PYTHON_ROOT}/libs/python310.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")
file(INSTALL "${PYTHON_ROOT}/libs/python3.lib" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/lib")

# Binaries (DLLs)
file(INSTALL "${PYTHON_ROOT}/python310.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/bin")
file(INSTALL "${PYTHON_ROOT}/python3.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/bin")

file(INSTALL "${PYTHON_ROOT}/python310.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")
file(INSTALL "${PYTHON_ROOT}/python3.dll" DESTINATION "${CURRENT_PACKAGES_DIR}/debug/bin")

# Copyright
file(WRITE "${CURRENT_PACKAGES_DIR}/share/${PORT}/copyright" "Python 3.10 Local Overlay")

