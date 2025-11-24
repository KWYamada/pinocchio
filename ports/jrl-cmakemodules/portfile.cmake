vcpkg_from_github(
    OUT_SOURCE_PATH SOURCE_PATH
    REPO jrl-umi3218/jrl-cmakemodules
    REF master
    SHA512 29b10291c4514c9e539b736ebe67a4f19f27d838c1c728bf0f9b308264fd5b0e06c3b569f3bec7d25eced1f07f3d03a80b7a4a32f5277dbb6e340eba6cb381aa
    HEAD_REF master
)

# Just copy the files to share/jrl-cmakemodules
file(COPY "${SOURCE_PATH}/" DESTINATION "${CURRENT_PACKAGES_DIR}/share/jrl-cmakemodules")

# Create a config file that defines the target and properties expected by eigenpy/pinocchio
file(WRITE "${CURRENT_PACKAGES_DIR}/share/jrl-cmakemodules/jrl-cmakemodules-config.cmake"
"
# Add this directory to module path so include(base.cmake) works if path is set
list(APPEND CMAKE_MODULE_PATH \"\${CMAKE_CURRENT_LIST_DIR}\")

# Create imported target
if(NOT TARGET jrl-cmakemodules::jrl-cmakemodules)
    add_library(jrl-cmakemodules::jrl-cmakemodules INTERFACE IMPORTED)
    
    # Point INTERFACE_INCLUDE_DIRECTORIES to this directory (where base.cmake lives)
    # Pinocchio/Eigenpy use this property to find the path to base.cmake
    set_target_properties(jrl-cmakemodules::jrl-cmakemodules PROPERTIES
        INTERFACE_INCLUDE_DIRECTORIES \"\${CMAKE_CURRENT_LIST_DIR}\"
    )
endif()

set(jrl-cmakemodules_FOUND TRUE)
"
)

# Create a dummy include dir to satisfy vcpkg
file(MAKE_DIRECTORY "${CURRENT_PACKAGES_DIR}/include")

file(INSTALL "${SOURCE_PATH}/LICENSE" DESTINATION "${CURRENT_PACKAGES_DIR}/share/${PORT}" RENAME copyright)
