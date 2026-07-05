#----------------------------------------------------------------
# Generated CMake target import file.
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "HackRF::hackrf" for configuration ""
set_property(TARGET HackRF::hackrf APPEND PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)
set_target_properties(HackRF::hackrf PROPERTIES
  IMPORTED_LOCATION_NOCONFIG "${_IMPORT_PREFIX}/lib/libhackrf.so.0.10.0"
  IMPORTED_SONAME_NOCONFIG "libhackrf.so.0"
  )

list(APPEND _cmake_import_check_targets HackRF::hackrf )
list(APPEND _cmake_import_check_files_for_HackRF::hackrf "${_IMPORT_PREFIX}/lib/libhackrf.so.0.10.0" )

# Import target "HackRF::hackrf_static" for configuration ""
set_property(TARGET HackRF::hackrf_static APPEND PROPERTY IMPORTED_CONFIGURATIONS NOCONFIG)
set_target_properties(HackRF::hackrf_static PROPERTIES
  IMPORTED_LINK_INTERFACE_LANGUAGES_NOCONFIG "C"
  IMPORTED_LOCATION_NOCONFIG "${_IMPORT_PREFIX}/lib/libhackrf.a"
  )

list(APPEND _cmake_import_check_targets HackRF::hackrf_static )
list(APPEND _cmake_import_check_files_for_HackRF::hackrf_static "${_IMPORT_PREFIX}/lib/libhackrf.a" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
