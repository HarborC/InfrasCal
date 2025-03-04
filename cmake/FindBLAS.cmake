# Find BLAS library
#
# This module finds an installed library that implements the BLAS
# linear-algebra interface (see http://www.netlib.org/blas/).
# The list of libraries searched for is mainly taken
# from the autoconf macro file, acx_blas.m4 (distributed at
# http://ac-archive.sourceforge.net/ac-archive/acx_blas.html).
#
# This module sets the following variables:
#  BLAS_FOUND - set to true if a library implementing the BLAS interface
#    is found
#  BLAS_INCLUDE_DIR - Directories containing the BLAS header files
#  BLAS_DEFINITIONS - Compilation options to use BLAS
#  BLAS_LINKER_FLAGS - Linker flags to use BLAS (excluding -l
#    and -L).
#  BLAS_LIBRARIES_DIR - Directories containing the BLAS libraries.
#     May be null if BLAS_LIBRARIES contains libraries name using full path.
#  BLAS_LIBRARIES - List of libraries to link against BLAS interface.
#     May be null if the compiler supports auto-link (e.g. VC++).
#  BLAS_USE_FILE - The name of the cmake module to include to compile
#     applications or libraries using BLAS.
#
# The following variables control the behaviour of this module:
#
# BLAS_DIR:         Specify a custom directory where suitesparse is located
#                   libraries and headers will be searched for in
#                   ${BLAS_DIR}/include and ${BLAS_DIR}/lib
#
# This module was modified by CGAL team:
# - find BLAS library shipped with TAUCS
# - find libraries for a C++ compiler, instead of Fortran
# - added BLAS_INCLUDE_DIR, BLAS_DEFINITIONS and BLAS_LIBRARIES_DIR
# - removed BLAS95_LIBRARIES
#
# TODO (CGAL):
# - find CBLAS (http://www.netlib.org/cblas) on Unix?


include(CheckFunctionExists)


# This macro checks for the existence of the combination of fortran libraries
# given by _list.  If the combination is found, this macro checks (using the
# check_function_exists macro) whether can link against that library
# combination using the name of a routine given by _name using the linker
# flags given by _flags.  If the combination of libraries is found and passes
# the link test, LIBRARIES is set to the list of complete library paths that
# have been found and DEFINITIONS to the required definitions.
# Otherwise, LIBRARIES is set to FALSE.
# N.B. _prefix is the prefix applied to the names of all cached variables that
# are generated internally and marked advanced by this macro.
macro(check_fortran_libraries DEFINITIONS LIBRARIES _prefix _name _flags _list _path)
  #message("DEBUG: check_fortran_libraries(${_list} in ${_path})")

  # Check for the existence of the libraries given by _list
  set(_libraries_found TRUE)
  set(_libraries_work FALSE)
  set(${DEFINITIONS} "")
  set(${LIBRARIES} "")
  set(_combined_name)
  foreach(_library ${_list})
    set(_combined_name ${_combined_name}_${_library})

    if(_libraries_found)
      # search first in ${_path}
      find_library(${_prefix}_${_library}_LIBRARY
                  NAMES ${_library}
                  PATHS ${_path} NO_DEFAULT_PATH
                  )
      # if not found, search in environment variables and system
      if ( WIN32 )
        find_library(${_prefix}_${_library}_LIBRARY
                    NAMES ${_library}
                    PATHS ${BLAS_DIR}/lib ${BLAS_DIR} ENV LIB
                    )
      elseif ( APPLE )
        find_library(${_prefix}_${_library}_LIBRARY
                    NAMES ${_library}
                    PATHS ${BLAS_DIR}/lib /usr/local/lib /usr/lib /usr/local/lib64 /usr/lib64 ENV DYLD_LIBRARY_PATH
                    )
      else ()
        find_library(${_prefix}_${_library}_LIBRARY
                    NAMES ${_library}
                    PATHS ${BLAS_DIR}/lib ~/.linuxbrew/lib /usr/local/lib /usr/lib /usr/local/lib64 /usr/lib64 ENV LD_LIBRARY_PATH
                    )
      endif()
      #message("DEBUG: find_library(${_library}) = ${${_prefix}_${_library}_LIBRARY}")
      mark_as_advanced(${_prefix}_${_library}_LIBRARY)
      set(${LIBRARIES} ${${LIBRARIES}} ${${_prefix}_${_library}_LIBRARY})
      set(_libraries_found ${${_prefix}_${_library}_LIBRARY})
    endif(_libraries_found)
  endforeach(_library ${_list})
  if(_libraries_found)
    set(_libraries_found ${${LIBRARIES}})
  endif()

  # Test this combination of libraries with the Fortran/f2c interface.
  # We test the Fortran interface first as it is well standardized.
  if(_libraries_found AND NOT _libraries_work)
    set(${DEFINITIONS}  "-D${_prefix}_USE_F2C")
    set(${LIBRARIES}    ${_libraries_found})
    # Some C++ linkers require the f2c library to link with Fortran libraries.
    # I do not know which ones, thus I just add the f2c library if it is available.
    find_package( F2C QUIET )
    if ( F2C_FOUND )
      set(${DEFINITIONS}  ${${DEFINITIONS}} ${F2C_DEFINITIONS})
      set(${LIBRARIES}    ${${LIBRARIES}} ${F2C_LIBRARIES})
    endif()
    set(CMAKE_REQUIRED_DEFINITIONS  ${${DEFINITIONS}})
    set(CMAKE_REQUIRED_LIBRARIES    ${_flags} ${${LIBRARIES}})
    #message("DEBUG: CMAKE_REQUIRED_DEFINITIONS = ${CMAKE_REQUIRED_DEFINITIONS}")
    #message("DEBUG: CMAKE_REQUIRED_LIBRARIES = ${CMAKE_REQUIRED_LIBRARIES}")
    # Check if function exists with f2c calling convention (ie a trailing underscore)
    check_function_exists(${_name}_ ${_prefix}_${_name}_${_combined_name}_f2c_WORKS)
    #message("DEBUG: check_function_exists(${_name}_) = ${${_prefix}_${_name}_${_combined_name}_f2c_WORKS}")
    set(CMAKE_REQUIRED_DEFINITIONS} "")
    set(CMAKE_REQUIRED_LIBRARIES    "")
    mark_as_advanced(${_prefix}_${_name}_${_combined_name}_f2c_WORKS)
    set(_libraries_work ${${_prefix}_${_name}_${_combined_name}_f2c_WORKS})
  endif(_libraries_found AND NOT _libraries_work)

  # If not found, test this combination of libraries with a C interface.
  # A few implementations (ie ACML) provide a C interface. Unfortunately, there is no standard.
  if(_libraries_found AND NOT _libraries_work)
    set(${DEFINITIONS} "")
    set(${LIBRARIES}   ${_libraries_found})
    set(CMAKE_REQUIRED_DEFINITIONS "")
    set(CMAKE_REQUIRED_LIBRARIES   ${_flags} ${${LIBRARIES}})
    #message("DEBUG: CMAKE_REQUIRED_LIBRARIES = ${CMAKE_REQUIRED_LIBRARIES}")
    check_function_exists(${_name} ${_prefix}_${_name}${_combined_name}_WORKS)
    #message("DEBUG: check_function_exists(${_name}) = ${${_prefix}_${_name}${_combined_name}_WORKS}")
    set(CMAKE_REQUIRED_LIBRARIES "")
    mark_as_advanced(${_prefix}_${_name}${_combined_name}_WORKS)
    set(_libraries_work ${${_prefix}_${_name}${_combined_name}_WORKS})
  endif(_libraries_found AND NOT _libraries_work)

  # on failure
  if(NOT _libraries_work)
    set(${DEFINITIONS} "")
    set(${LIBRARIES}   FALSE)
  endif()
  #message("DEBUG: ${DEFINITIONS} = ${${DEFINITIONS}}")
  #message("DEBUG: ${LIBRARIES} = ${${LIBRARIES}}")
endmacro(check_fortran_libraries)


#
# main
#

# Is it already configured?
if (BLAS_LIBRARIES_DIR OR BLAS_LIBRARIES)

  set(BLAS_FOUND TRUE)

else()

  # reset variables
  set( BLAS_INCLUDE_DIR "" )
  set( BLAS_DEFINITIONS "" )
  set( BLAS_LINKER_FLAGS "" )
  set( BLAS_LIBRARIES "" )
  set( BLAS_LIBRARIES_DIR "" )

  # Look first for the TAUCS library distributed with CGAL in auxiliary/taucs.
  # Set CGAL_TAUCS_FOUND, CGAL_TAUCS_INCLUDE_DIR and CGAL_TAUCS_LIBRARIES_DIR.
  #include(CGAL_Locate_CGAL_TAUCS)

  # Search for BLAS in CGAL_TAUCS_INCLUDE_DIR/CGAL_TAUCS_LIBRARIES_DIR (TAUCS shipped with CGAL)...
  if(CGAL_TAUCS_FOUND AND CGAL_AUTO_LINK_ENABLED)

    # if VC++: done
    set( BLAS_INCLUDE_DIR    "${CGAL_TAUCS_INCLUDE_DIR}" )
    set( BLAS_LIBRARIES_DIR  "${CGAL_TAUCS_LIBRARIES_DIR}" )

  # ...else search for BLAS in $BLAS_LIB_DIR environment variable
  else(CGAL_TAUCS_FOUND AND CGAL_AUTO_LINK_ENABLED)

    #
    # Search for BLAS in possible libraries
    # in $BLAS_LIB_DIR environment variable and in usual places.
    #

    # BLAS in ATLAS library? (http://math-atlas.sourceforge.net/)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      cblas_dgemm
      ""
      "cblas;f77blas;atlas"
      "${BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in PhiPACK libraries? (requires generic BLAS lib, too)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "sgemm;dgemm;blas"
      "${BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in Alpha CXML library?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "cxml"
      "${BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in Alpha DXML library? (now called CXML, see above)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "dxml"
      "${BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in Sun Performance library?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      "-xlic_lib=sunperf"
      "sunperf;sunmath"
      "${BLAS_LIB_DIR}"
      )
      if(BLAS_LIBRARIES)
        # Extra linker flag
        set(BLAS_LINKER_FLAGS "-xlic_lib=sunperf")
      endif()
    endif()

    # BLAS in SCSL library?  (SGI/Cray Scientific Library)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "scsl"
      "${BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in SGIMATH library?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "complib.sgimath"
      "${BLAS_LIB_DIR}"
      )
    endif()

    # BLAS in IBM ESSL library? (requires generic BLAS lib, too)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "essl;blas"
      "${BLAS_LIB_DIR}"
      )
    endif()

    # intel mkl 10 library?
  # TODO: add shared variants
    if (WIN32)
      # intel mkl library? (static, 32bit)
      if(NOT BLAS_LIBRARIES)
        check_fortran_libraries(
        BLAS_DEFINITIONS
        BLAS_LIBRARIES
        BLAS
        SGEMM
        ""
        "mkl_intel_c;mkl_intel_thread;mkl_core;libiomp5md"
        "${MKL_LIB_DIR} ${BLAS_LIB_DIR}"
        )
      endif()

    # intel mkl library? (static, ia64 and em64t 64 bit)
      if(NOT BLAS_LIBRARIES)
        check_fortran_libraries(
        BLAS_DEFINITIONS
        BLAS_LIBRARIES
        BLAS
        SGEMM
        ""
        "mkl_intel_lp64;mkl_intel_thread_lp64;mkl_core;libiomp5md"
        "${MKL_LIB_DIR} ${BLAS_LIB_DIR}"
        )
      endif()
    else(WIN32)
      # intel mkl library? (static, 32bit)
      if(NOT BLAS_LIBRARIES)
        check_fortran_libraries(
        BLAS_DEFINITIONS
        BLAS_LIBRARIES
        BLAS
        sgemm
        ""
        "mkl_intel;mkl_intel_thread;mkl_core;iomp5;pthread"
        "${MKL_LIB_DIR} ${BLAS_LIB_DIR}"
        )
      endif()
      
    # intel mkl library? (static, ia64 and em64t 64 bit)
      if(NOT BLAS_LIBRARIES)
        check_fortran_libraries(
        BLAS_DEFINITIONS
        BLAS_LIBRARIES
        BLAS
        sgemm
        ""
        "mkl_intel_lp64;mkl_intel_thread_lp64;mkl_core;iomp5;pthread"
        "${MKL_LIB_DIR} ${BLAS_LIB_DIR}"
        )
      endif()
    endif (WIN32)

    # older versions of intel mkl libs

    # intel mkl library? (shared)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "mkl;guide;pthread"
      "${MKL_LIB_DIR} ${BLAS_LIB_DIR}"
      )
    endif()

    # intel mkl library? (static, 32bit)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "mkl_ia32;guide;pthread"
      "${MKL_LIB_DIR} ${BLAS_LIB_DIR}"
      )
    endif()

  # intel mkl library? (static, ia64 64bit)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "mkl_ipf;guide;pthread"
      "${MKL_LIB_DIR} ${BLAS_LIB_DIR}"
      )
    endif()

    # intel mkl library? (static, em64t 64bit)
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "mkl_em64t;guide;pthread"
      "${MKL_LIB_DIR} ${BLAS_LIB_DIR}"
      )
    endif()

    #BLAS in acml library?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "acml"
      "${BLAS_LIB_DIR}"
      )
    endif()

    # Apple BLAS library?
    if(NOT BLAS_LIBRARIES)
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "Accelerate"
      "${BLAS_LIB_DIR}"
      )
    endif()

    if ( NOT BLAS_LIBRARIES )
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "vecLib"
      "${BLAS_LIB_DIR}"
      )
    endif ( NOT BLAS_LIBRARIES )

    # Generic BLAS library?
    # This configuration *must* be the last try as this library is notably slow.
    if ( NOT BLAS_LIBRARIES )
      check_fortran_libraries(
      BLAS_DEFINITIONS
      BLAS_LIBRARIES
      BLAS
      sgemm
      ""
      "blas"
      "${BLAS_LIB_DIR}"
      )
    endif()

  endif(CGAL_TAUCS_FOUND AND CGAL_AUTO_LINK_ENABLED)

  if(BLAS_LIBRARIES_DIR OR BLAS_LIBRARIES)
    set(BLAS_FOUND TRUE)
  else()
    find_package(OpenBLAS)
    if(OpenBLAS_FOUND)
        set(BLAS_FOUND TRUE)
        set(BLAS_INCLUDE_DIR ${OpenBLAS_INCLUDE_DIRS})
        set(BLAS_LIBRARIES ${OpenBLAS_LIBRARIES})
    else()
        set(BLAS_FOUND FALSE)
    endif()
  endif()

  if(NOT BLAS_FIND_QUIETLY)
    if(BLAS_FOUND)
      message(STATUS "A library with BLAS API found.")
    else(BLAS_FOUND)
      if(BLAS_FIND_REQUIRED)
        message(FATAL_ERROR "A required library with BLAS API not found. Please specify library location.")
      else()
        message(STATUS "A library with BLAS API not found. Please specify library location.")
      endif()
    endif(BLAS_FOUND)
  endif(NOT BLAS_FIND_QUIETLY)

  # Add variables to cache
  set( BLAS_INCLUDE_DIR   "${BLAS_INCLUDE_DIR}" 
                          CACHE PATH "Directories containing the BLAS header files" FORCE )
  set( BLAS_DEFINITIONS   "${BLAS_DEFINITIONS}" 
                          CACHE STRING "Compilation options to use BLAS" FORCE )
  set( BLAS_LINKER_FLAGS  "${BLAS_LINKER_FLAGS}" 
                          CACHE STRING "Linker flags to use BLAS" FORCE )
  set( BLAS_LIBRARIES     "${BLAS_LIBRARIES}" 
                          CACHE FILEPATH "BLAS libraries name" FORCE )
  set( BLAS_LIBRARIES_DIR "${BLAS_LIBRARIES_DIR}" 
                          CACHE PATH "Directories containing the BLAS libraries" FORCE )

  #message("DEBUG: BLAS_INCLUDE_DIR = ${BLAS_INCLUDE_DIR}")
  #message("DEBUG: BLAS_DEFINITIONS = ${BLAS_DEFINITIONS}")
  #message("DEBUG: BLAS_LINKER_FLAGS = ${BLAS_LINKER_FLAGS}")
  #message("DEBUG: BLAS_LIBRARIES = ${BLAS_LIBRARIES}")
  #message("DEBUG: BLAS_LIBRARIES_DIR = ${BLAS_LIBRARIES_DIR}")
  #message("DEBUG: BLAS_FOUND = ${BLAS_FOUND}")

endif(BLAS_LIBRARIES_DIR OR BLAS_LIBRARIES)

if(BLAS_FOUND)
  set(BLAS_FOUND ${BLAS_FOUND} CACHE INTERNAL "")
  set(BLAS_USE_FILE "CGAL_UseBLAS")
endif(BLAS_FOUND)
