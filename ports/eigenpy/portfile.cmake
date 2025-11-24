vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO stack-of-tasks/eigenpy
    REF v3.8.0
    SHA512 c713fe72321d5e5d5d3a28057359ff61f3524e29785517bc10b83acb84688b3eb40286753e0fbf0b33415da26ec1a7bfd1fe0fbe43ebd5833bd4d466e7ce0347
    HEAD_REF master
)

# Bump CMake version requirement for compatibility with newer jrl-cmakemodules
vcpkg_replace_string(
    "${SOURCE_PATH}/CMakeLists.txt"
    "cmake_minimum_required(VERSION 3.10)"
    "cmake_minimum_required(VERSION 3.22)"
)

# Patch CMakeLists.txt to respect JRL_CMAKE_MODULES variable
vcpkg_replace_string(
    "${SOURCE_PATH}/CMakeLists.txt"
    "set(JRL_CMAKE_MODULES \"\${CMAKE_CURRENT_LIST_DIR}/cmake\")"
    "if(NOT DEFINED JRL_CMAKE_MODULES)\n  set(JRL_CMAKE_MODULES \"\${CMAKE_CURRENT_LIST_DIR}/cmake\")\nendif()"
)

# Patch CMakeLists.txt to conditionally build tests
vcpkg_replace_string(
    "${SOURCE_PATH}/CMakeLists.txt"
    "add_subdirectory(unittest)"
    "if(BUILD_TESTING)\n  add_subdirectory(unittest)\nendif()"
)

# Patch register.cpp and numpy.cpp to fix MSVC C2664 error (PyArray_DescrProto vs PyArray_Descr)
vcpkg_replace_string(
    "${SOURCE_PATH}/src/numpy.cpp"
    "int call_PyArray_RegisterDataType(PyArray_Descr* dtype)"
    "int call_PyArray_RegisterDataType(PyArray_DescrProto* dtype)"
)
vcpkg_replace_string(
    "${SOURCE_PATH}/include/eigenpy/numpy.hpp"
    "EIGENPY_DLLAPI int call_PyArray_RegisterDataType(PyArray_Descr* dtype);"
    "EIGENPY_DLLAPI int call_PyArray_RegisterDataType(PyArray_DescrProto* dtype);"
)

# Force usage of our venv python which has numpy installed
get_filename_component(PROJECT_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../" ABSOLUTE)
set(PYTHON_EXECUTABLE "${PROJECT_ROOT}/venv_build/Scripts/python.exe")

vcpkg_cmake_configure(
    SOURCE_PATH "${SOURCE_PATH}"
    OPTIONS
        -DBUILD_PYTHON_INTERFACE=ON
        -DGENERATE_PYTHON_STUBS=OFF
        -DINSTALL_DOCUMENTATION=OFF
        -DBUILD_TESTING=OFF
        "-DJRL_CMAKE_MODULES=${CURRENT_INSTALLED_DIR}/share/jrl-cmakemodules"
        "-DPython3_EXECUTABLE=${PYTHON_EXECUTABLE}"
        "-DPYTHON_EXECUTABLE=${PYTHON_EXECUTABLE}"
)

vcpkg_cmake_install()

vcpkg_cmake_config_fixup(
    PACKAGE_NAME eigenpy
    CONFIG_PATH lib/cmake/eigenpy
)

file(REMOVE_RECURSE "${CURRENT_PACKAGES_DIR}/debug/include")
file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
