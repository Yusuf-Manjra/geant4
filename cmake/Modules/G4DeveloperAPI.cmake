#.rst:
# G4DeveloperAPI
# --------------
#
# .. code-block::cmake
#
#   include(G4DeveloperAPI)
#
# CMake functions and macros for declaring and working with build
# products of Geant4.
#

#-----------------------------------------------------------------
# License and Disclaimer
#
# The  Geant4 software  is  copyright of the Copyright Holders  of
# the Geant4 Collaboration.  It is provided  under  the terms  and
# conditions of the Geant4 Software License,  included in the file
# LICENSE and available at  http://cern.ch/geant4/license .  These
# include a list of copyright holders.
#
# Neither the authors of this software system, nor their employing
# institutes,nor the agencies providing financial support for this
# work  make  any representation or  warranty, express or implied,
# regarding  this  software system or assume any liability for its
# use.  Please see the license in the file  LICENSE  and URL above
# for the full disclaimer and the limitation of liability.
#
# This  code  implementation is the result of  the  scientific and
# technical work of the GEANT4 collaboration.
# By using,  copying,  modifying or  distributing the software (or
# any work based  on the software)  you  agree  to acknowledge its
# use  in  resulting  scientific  publications,  and indicate your
# acceptance of all terms of the Geant4 Software license.
#
#-----------------------------------------------------------------

include_guard(DIRECTORY)

#-----------------------------------------------------------------------
#.rst:
# Module Commands
# ^^^^^^^^^^^^^^^
#
# .. cmake:command:: geant4_add_module
#
#   .. code-block:: cmake
#
#     geant4_add_module(<name>
#                       PUBLIC_HEADERS header1 [header2 ...]
#                       [SOURCES source1 [source2 ...]])
#
#   Add a Geant4 module called ``<name>`` to the project, composed
#   of the source files listed in the ``PUBLIC_HEADERS`` and ``SOURCES``
#   arguments. The ``<name>`` must be unique within the project.
#   The directory in which the module is added (i.e. ``CMAKE_CURRENT_LIST_DIR``
#   for the CMake script in which ``geant4_add_module`` is called) must contain:
#
#   * An ``include`` subdirectory for the public headers
#   * A ``src`` subdirectory for source files if the module provides these
#
#   The ``PUBLIC_HEADERS`` argument must list the headers comprising the
#   public interface of the module. If a header is supplied as a relative path,
#   this is interpreted as being relative to the ``include`` subdirectory of the module.
#   Absolute paths may also be supplied, e.g. if headers are generated by the project.
#
#   The ``SOURCES`` argument should list any source files for the module.
#   If a source is is supplied as a relative path, this is interpreted as being
#   relative to the ``src`` subdirectory of the module. Absolute paths may
#   also be supplied, e.g. if sources are generated by the project.
#
function(geant4_add_module _name)
  __geant4_module_assert_not_exists(${_name})
  set_property(GLOBAL APPEND PROPERTY GEANT4_DEFINED_MODULES ${_name})
  cmake_parse_arguments(G4ADDMOD
    ""
    ""
    "PUBLIC_HEADERS;SOURCES"
    ${ARGN}
    )
  __geant4_assert_no_unparsed_arguments(G4ADDMOD geant4_add_module)

  # - Check required directory structure at definition point
  # Headers always
  if(NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/include")
    message(FATAL_ERROR "Missing required 'include' subdirectory for module '${_name}' at '${CMAKE_CURRENT_LIST_DIR}'")
  endif()

  # Sources if defined
  if(G4ADDMOD_SOURCES AND (NOT EXISTS "${CMAKE_CURRENT_LIST_DIR}/src"))
    message(FATAL_ERROR "Missing required 'src' subdirectory for module '${_name}' at '${CMAKE_CURRENT_LIST_DIR}'")
  endif()

  # Compose header/source lists
  set(__tmp_HEADERS)
  foreach(__elem ${G4ADDMOD_PUBLIC_HEADERS})
    if(IS_ABSOLUTE "${__elem}")
      list(APPEND __tmp_HEADERS "${__elem}")
    else()
      list(APPEND __tmp_HEADERS "${CMAKE_CURRENT_LIST_DIR}/include/${__elem}")
    endif()
  endforeach()
  geant4_set_module_property(${_name} PROPERTY PUBLIC_HEADERS ${__tmp_HEADERS})

  set(__tmp_SOURCES)
  foreach(__elem ${G4ADDMOD_SOURCES})
    if(IS_ABSOLUTE "${__elem}")
      list(APPEND __tmp_SOURCES "${__elem}")
    else()
      list(APPEND __tmp_SOURCES "${CMAKE_CURRENT_LIST_DIR}/src/${__elem}")
    endif()
  endforeach()
  geant4_set_module_property(${_name} PROPERTY SOURCES ${__tmp_SOURCES})

  # Set the default include directory for this module
  geant4_module_include_directories(${_name} PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/include>)

  # Backward compatibility shim for direct usage of build directory
  # Not all clients (esp. those using ROOT) may not fully support usage requirements
  # and expect GEANT4_INCLUDE_DIRS to be complete
  set_property(GLOBAL APPEND PROPERTY GEANT4_BUILDTREE_INCLUDE_DIRS "${CMAKE_CURRENT_LIST_DIR}/include")

  # Record where we're defined so we can pop the file into IDEs
  geant4_set_module_property(${_name} PROPERTY CMAKE_LIST_FILE "${CMAKE_CURRENT_LIST_FILE}")
endfunction()

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: geant4_module_include_directories
#
#   .. code-block:: cmake
#
#     geant4_module_include_directories(<module>
#                                       [PUBLIC pub1 [pub2 ...]
#                                       [PRIVATE pri1 [pri2 ...]
#                                       [INTERFACE int1 [int2 ...])
#
#   Add include directories to given module.
#
function(geant4_module_include_directories _module)
  __geant4_module_assert_exists(${_module})
  cmake_parse_arguments(G4MODINCDIR
    ""
    ""
    "PUBLIC;PRIVATE;INTERFACE"
    ${ARGN}
    )
  __geant4_assert_no_unparsed_arguments(G4MODINCDIR geant4_module_include_directories)

  foreach(_dir ${G4MODINCDIR_PUBLIC})
    geant4_set_module_property(${_module} APPEND PROPERTY PUBLIC_INCLUDE_DIRECTORIES ${_dir})
  endforeach()

  foreach(_dir ${G4MODINCDIR_PRIVATE})
    geant4_set_module_property(${_module} APPEND PROPERTY PRIVATE_INCLUDE_DIRECTORIES ${_dir})
  endforeach()

  foreach(_dir ${G4MODINCDIR_INTERFACE})
    geant4_set_module_property(${_module} APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES ${_dir})
  endforeach()
endfunction()

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: geant4_module_link_libraries
#
#   .. code-block:: cmake
#
#     geant4_module_link_libraries(<module>
#                                  [PUBLIC pub1 [pub2 ...]
#                                  [PRIVATE pri1 [pri2 ...]
#                                  [INTERFACE int1 [int2 ...])
#
#   Link ``<module>`` to given targets.
#
function(geant4_module_link_libraries _module)
  __geant4_module_assert_exists(${_module})
  cmake_parse_arguments(G4MODLINKLIB
    ""
    ""
    "PUBLIC;PRIVATE;INTERFACE"
    ${ARGN}
    )
  __geant4_assert_no_unparsed_arguments(G4MODLINKLIB geant4_module_link_libraries)

  foreach(_lib ${G4MODLINKLIB_PUBLIC})
    geant4_set_module_property(${_module} APPEND PROPERTY PUBLIC_LINK_LIBRARIES ${_lib})
  endforeach()

  foreach(_lib ${G4MODLINKLIB_PRIVATE})
    geant4_set_module_property(${_module} APPEND PROPERTY PRIVATE_LINK_LIBRARIES ${_lib})
  endforeach()

  foreach(_dir ${G4MODLINKLIB_INTERFACE})
    geant4_set_module_property(${_module} APPEND PROPERTY INTERFACE_LINK_LIBRARIES ${_lib})
  endforeach()
endfunction()

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: geant4_module_compile_definitions
#
#   .. code-block:: cmake
#
#    geant4_module_compile_definitions(<module>
#                                      [PUBLIC pub1 [pub2 ...]
#                                      [PRIVATE pri1 [pri2 ...]
#                                      [INTERFACE int1 [int2 ...])
#
#   Add compile definitions for this module
#
#   Use cases:
#   1. workarounds when a config header isn't suitable
#
#   Needs care with DLLs if used for import/export declspecs
#   Application of specific defs to single files not considered
#   Expected that uses cases here minimal, and developers should
#   in that case use set_source_files_properties or similar
#   directly.
#
function(geant4_module_compile_definitions _module)
  __geant4_module_assert_exists(${_module})
  cmake_parse_arguments(G4MODCOMPILEDEF
    ""
    ""
    "PUBLIC;PRIVATE;INTERFACE"
    ${ARGN}
    )
  __geant4_assert_no_unparsed_arguments(G4MODCOMPILEDEF geant4_module_compile_definitions)

  foreach(_lib ${G4MODCOMPILEDEF_PUBLIC})
    geant4_set_module_property(${_module} APPEND PROPERTY PUBLIC_COMPILE_DEFINITIONS ${_lib})
  endforeach()

  foreach(_lib ${G4MODCOMPILEDEF_PRIVATE})
    geant4_set_module_property(${_module} APPEND PROPERTY PRIVATE_COMPILE_DEFINITIONS ${_lib})
  endforeach()

  foreach(_dir ${G4MODCOMPILEDEF_INTERFACE})
    geant4_set_module_property(${_module} APPEND PROPERTY INTERFACE_COMPILE_DEFINITIONS ${_lib})
  endforeach()
endfunction()

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: geant4_get_modules
#
#   .. code-block:: cmake
#
#     geant4_get_modules(<result>)
#
#   Store the list of currently defined modules in the variable ``<result>``.
#
function(geant4_get_modules _result)
  get_property(__tmp GLOBAL PROPERTY GEANT4_DEFINED_MODULES)
  set(${_result} ${__tmp} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: geant4_has_module
#
#   .. code-block:: cmake
#
#     geant4_has_module(<result> <name>)
#
#   Set variable ``<result>`` to a boolean which will be true if the module
#   ``<name>`` is defined.
#
function(geant4_has_module _result _name)
  set(__exists FALSE)

  geant4_get_modules(__tmp)
  if(__tmp)
    list(FIND __tmp ${_name} __index)
    if(__index GREATER -1)
      set(__exists TRUE)
    endif()
  endif()

  set(${_result} ${__exists} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------
#.rst:
# Module Properties
# =================
#
# A Geant4 module stores its build and usage requirements in a series
# of properties:
#
# * ``PUBLIC_HEADERS``
# * ``PRIVATE_HEADERS``
# * ``SOURCES``
# * ``PRIVATE_COMPILE_DEFINITIONS``
# * ``PUBLIC_COMPILE_DEFINITIONS``
# * ``INTERFACE_COMPILE_DEFINITIONS``
# * ``PRIVATE_INCLUDE_DIRECTORIES``
# * ``PUBLIC_INCLUDE_DIRECTORIES``
# * ``INTERFACE_INCLUDE_DIRECTORIES``
# * ``PRIVATE_LINK_LIBRARIES``
# * ``PUBLIC_LINK_LIBRARIES``
# * ``INTERFACE_LINK_LIBRARIES``
# * ``PARENT_TARGET``
# * ``CMAKE_LIST_FILE``
# * ``GLOBAL_DEPENDENCIES``
#
# The properties of a module may be queried and set using the following
# commands.

# .. cmake:command:: geant4_get_module_property
#
#   .. code-block:: cmake
#
#     geant4_get_module_property(<result> <module> <property>)
#
#   Store value of property ``<property>`` for ``<module>`` in variable
#   ``<result>``.
#
#   If ``<property>`` is not a valid module property, a FATAL_ERROR is
#   emitted.
#
function(geant4_get_module_property _output _module _propertyname)
  __geant4_module_assert_exists(${_module})
  __geant4_module_validate_property(${_propertyname})
  get_property(__result GLOBAL PROPERTY ${_module}_${_propertyname})
  set(${_output} ${__result} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: geant4_set_module_property
#
#   .. code-block:: cmake
#
#     geant4_set_module_property(<module>
#                                [APPEND | APPEND_STRING]
#                                PROPERTY <property> <value>)
#
#   Set property ``<property>`` of module ``<module>`` to ``<value>``.
#
#   If ``APPEND`` is supplied, ``<value>`` will be appended to any existing
#   value for the property as a list.
#
#   If ``APPEND_STRING`` is supplied, ``<value>`` will be appended to any existing
#   value for the property as a string. This option is mutually exclusive with
#   ``APPEND``.
#
#   If ``<property>`` is not a valid module property, a FATAL_ERROR is
#   emitted.
#
function(geant4_set_module_property _module)
  __geant4_module_assert_exists(${_module})
  cmake_parse_arguments(G4SMP
    "APPEND;APPEND_STRING"
    ""
    "PROPERTY"
    ${ARGN}
    )
  __geant4_assert_no_unparsed_arguments(G4SMP geant4_set_module_property)


  # Append/Append_string are mutually exclusive
  if(G4SMP_APPEND AND G4SMP_APPEND_STRING)
    message(FATAL_ERROR "geant4_set_module_property: cannot set both APPEND and APPEND_STRING")
  elseif(G4SMP_APPEND)
    set(G4SMP_APPEND_MODE "APPEND")
  elseif(G4SMP_APPEND_MODE)
    set(G4SMP_APPEND_MODE "APPEND_STRING")
  endif()

  # First element of PROPERTY list is prop name
  list(GET G4SMP_PROPERTY 0 G4SMP_PROPERTY_NAME)
  if(NOT G4SMP_PROPERTY_NAME)
    message(FATAL_ERROR "geant4_set_module_property: Required PROPERTY argument is missing")
  endif()

  __geant4_module_validate_property(${G4SMP_PROPERTY_NAME})
  # Remainder is arguments, so strip first element
  list(REMOVE_AT G4SMP_PROPERTY 0)

  set_property(GLOBAL ${G4SMP_APPEND_MODE} PROPERTY ${_module}_${G4SMP_PROPERTY_NAME} ${G4SMP_PROPERTY})
endfunction()

#-----------------------------------------------------------------------
#.rst:
# Category Commands
# ^^^^^^^^^^^^^^^^^
#
# .. cmake:command:: geant4_add_category
#
#   .. code-block:: cmake
#
#     geant4_add_category(<name> MODULES <module> [<module> ...])
#
#   Add a Geant4 category ``<name>`` to the project, composed of the modules
#   supplied in the ``MODULES`` list.
#
#   Calling this function does not create an actual CMake library target.
#   Because modules declare dependencies on modules rather than libraries, we
#   defer creation of library targets to after creation of categories, which
#   allows resolution of module <-> category use. Additionally, category specific
#   actions such as install may be added.
#
function(geant4_add_category _name)
  # Check existence? final add_library will warn, but may wish to double check
  set_property(GLOBAL APPEND PROPERTY GEANT4_DEFINED_CATEGORIES ${_name})
  cmake_parse_arguments(G4ADDCAT
    ""
    ""
    "MODULES"
    ${ARGN}
    )
  # - Modules must not be empty (Could also just be ARGN)
  if(NOT G4ADDCAT_MODULES)
    message(FATAL_ERROR "geant4_add_category: Missing/empty 'MODULES' argument")
  endif()

  # Compose Category from Modules
  foreach(__g4module ${G4ADDCAT_MODULES})
    # Module must not have been composed already
    geant4_get_module_property(_parent ${__g4module} PARENT_TARGET)
    if(${_parent})
      message(FATAL_ERROR "geant4_add_category: trying to compose category '${_name}' using module '${__g4module}' which is already composed into category '${_parent}'")
    endif()

    # Compose it
    geant4_set_module_property(${__g4module} PROPERTY PARENT_TARGET ${_name})
    set_property(GLOBAL APPEND PROPERTY GEANT4_CATEGORIES_${_name}_MODULES ${__g4module})

    geant4_get_module_property(_headers ${__g4module} PUBLIC_HEADERS)
    set_property(GLOBAL APPEND PROPERTY GEANT4_CATEGORIES_${_name}_PUBLIC_HEADERS ${_headers})
  endforeach()

  # As we do not create a physical target, store the script in which we're called
  set_property(GLOBAL PROPERTY GEANT4_CATEGORIES_${_name}_CMAKE_LIST_FILE "${CMAKE_CURRENT_LIST_FILE}")
endfunction()

#-----------------------------------------------------------------------
# Resolve a list of links
# These may include Geant4 modules as well as standard targets or other expressions
# Resolve Modules to PARENT_TARGET, removing duplicates
# Leave other links unchanged
function(geant4_resolve_link_libraries _list)
  set(_resolved_list )
  foreach(__lib ${${_list}})
    # If "library" is a module, resolve it to PARENT_TARGET
    geant4_has_module(__is_module ${__lib})
    if(__is_module)
      geant4_get_module_property(__parent_lib ${__lib} PARENT_TARGET)
      list(APPEND _resolved_list ${__parent_lib})
    else()
      list(APPEND _resolved_list ${__lib})
    endif()
  endforeach()
  if(_resolved_list)
    list(REMOVE_DUPLICATES _resolved_list)
  endif()
  set(${_list} ${_resolved_list} PARENT_SCOPE)
endfunction()

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: geant4_compose_targets
#
#   .. code-block:: cmake
#
#     geant4_compose_targets()
#
#   Create physical SHARED/STATIC library targets from the defined Geant4
#   categories and modules.
#
#   Can only be called once, and must be done so after all Geant4 libraries
#   and modules are defined.
#
function(geant4_compose_targets)
  get_property(__alreadyCalled GLOBAL PROPERTY GEANT4_COMPOSE_TARGETS_CALLED)
  if(__alreadyCalled)
    get_property(__callsite GLOBAL PROPERTY GEANT4_COMPOSE_TARGETS_LIST_FILE)
    message(FATAL_ERROR "geant4_compose_targets already called from ${__callsite}")
  endif()

  # Check that every defined module is composed
  geant4_get_modules(__g4definedmodules)
  foreach(__module ${__g4definedmodules})
    geant4_get_module_property(__iscomposed ${__module} PARENT_TARGET)
    if(NOT __iscomposed)
      message(FATAL_ERROR "Geant4 module '${__module}' is not composed into any category")
    endif()
  endforeach()

  # - For each module, write out files for
  # 1. module -> used modules adjacency list for detecting module-module cycles
  file(WRITE "${PROJECT_BINARY_DIR}/G4ModuleAdjacencyList.txt" "# Geant4 Module - Module Adjacencies\n")
  foreach(__module ${__g4definedmodules})
    # Adjacency list - take all dependencies
    geant4_get_module_property(__publicdeps ${__module} PUBLIC_LINK_LIBRARIES)
    geant4_get_module_property(__privatedeps ${__module} PRIVATE_LINK_LIBRARIES)
    geant4_get_module_property(__interfacedeps ${__module} INTERFACE_LINK_LIBRARIES)
    set(__alldeps_l ${__publicdeps} ${__privatedeps} ${__interfacedeps})
    list(JOIN __alldeps_l " " __alldeps)
    file(APPEND "${PROJECT_BINARY_DIR}/G4ModuleAdjacencyList.txt" "${__module} ${__alldeps}\n")
  endforeach()

  # Process all defined libraries, except for G4{clhep,expat,ptl}{-static}
  # These are corner cases because its call to add_library happens
  # at a different (lower) directory level than all the other targets
  # This means we cannot install it here. That's left to it
  get_property(__g4definedlibraries GLOBAL PROPERTY GEANT4_DEFINED_CATEGORIES)
  list(REMOVE_ITEM __g4definedlibraries G4clhep G4clhep-static G4expat G4expat-static G4ptl G4ptl-static)
  set(__g4builtlibraries)
  set(__g4public_headers)

  foreach(__g4lib ${__g4definedlibraries})
    if(BUILD_SHARED_LIBS)
      __geant4_add_library(${__g4lib} SHARED)
      list(APPEND __g4builtlibraries ${__g4lib})
    endif()

    if(BUILD_STATIC_LIBS)
      __geant4_add_library(${__g4lib} STATIC)
      list(APPEND __g4builtlibraries ${__g4lib}-static)
    endif()

    get_property(__headers GLOBAL PROPERTY GEANT4_CATEGORIES_${__g4lib}_PUBLIC_HEADERS)
    list(APPEND __g4public_headers ${__headers})
  endforeach()

  #-----------------------------------------------------------------------
  # TEMP INSTALL - do here purely to review exported links. Should be
  # factored out into separate function later.
  install(TARGETS ${__g4builtlibraries}
    EXPORT Geant4LibraryDepends
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}" COMPONENT Development
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}" COMPONENT Runtime
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}" COMPONENT Runtime
    INCLUDES DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME}")
  install(FILES ${__g4public_headers} DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME}" COMPONENT Development)

  set_property(GLOBAL PROPERTY GEANT4_COMPOSE_TARGETS_CALLED ON)
  set_property(GLOBAL PROPERTY GEANT4_COMPOSE_TARGETS_LIST_FILE "${CMAKE_CURRENT_LIST_FILE}")
endfunction()

#-----------------------------------------------------------------------
#.rst:
# Backward Compatibility Commands
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
#
# These commands implement the old module/library definition macros in
# terms of the new command set. They provide a facade allowing migration
# to the new interfaces with a controlled transition.
#
# As migration progresses, these commands will gradually be deprecated,
# with warnings issued about what to do at each stage.
#
# .. cmake:command:: geant4_define_module
#
#   .. code-block:: cmake
#
#     geant4_define_module(NAME <name>
#                          HEADERS header1 [header2 ...]
#                          SOURCES source1 [source2 ...]
#                          GRANULAR_DEPENDENCIES lib1 [lib2 ...]
#                          GLOBAL_DEPENDENCIES lib1 [lib2 ...]
#                          LINK_LIBRARIES lib1 [lib2 ...])
#
# DEPRECATED: Use :cmake:command:`geant4_add_module` to add a module with headers/sources,
# and :cmake:command:`geant4_module_link_libraries` to declare internal and external
# libraries to link to.
#
function(geant4_define_module)
  cmake_parse_arguments(G4DEFMOD
    ""
    "NAME"
    "HEADERS;SOURCES;GRANULAR_DEPENDENCIES;GLOBAL_DEPENDENCIES;LINK_LIBRARIES"
    ${ARGN}
    )
  __geant4_assert_no_unparsed_arguments(G4DEFMOD geant4_define_module)
  # HEADERS -> PUBLIC_HEADERS
  # SOURCES -> SOURCES
  geant4_add_module(${G4DEFMOD_NAME}
    PUBLIC_HEADERS ${G4DEFMOD_HEADERS}
    SOURCES ${G4DEFMOD_SOURCES}
    )

  # GRANULAR_DEPENDENCIES -> geant4_module_link_libraries(mod PUBLIC ...)
  # GLOBAL_DEPENDENCIES -> new property... Just record it for now, later
  # we need to link these to the physical library the module is composed into
  # checking that
  #  i) Granular -> Global link is complete, i.e. resolving granular deps results
  #     in same global link list.
  # Has to be stored separately because we want/need to check for full resolution of
  # the granular libs to the same set of global libs. That's needed to ensure we
  # can correct any missing links in existing GRANULAR_DEPENDENCIES lists.
  # (i.e. it's a transtional property)
  # LINK_LIBRARIES -> geant4_module_link_libraries(mod PUBLIC ...)

  geant4_module_link_libraries(${G4DEFMOD_NAME} PUBLIC ${G4DEFMOD_GRANULAR_DEPENDENCIES} ${G4DEFMOD_LINK_LIBRARIES})
  geant4_set_module_property(${G4DEFMOD_NAME} PROPERTY GLOBAL_DEPENDENCIES ${G4DEFMOD_GLOBAL_DEPENDENCIES})

  # When we are ready, start issuing a deprecation warning here, including instructions for
  # migration...
  #message(WARNING "Use of geant4_define_module is deprecated, please use... instead")
endfunction()

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: geant4_global_library_target
#
#   .. code-block:: cmake
#
#     geant4_global_library_target(NAME <name>
#                                  COMPONENTS file1 [file2 ...])
#
# DEPRECATED: Use :cmake:command:`geant4_add_library` to add a library with a list
# of modules.
#
# This function provides a facade around :cmake:command:`geant4_add_library` to
# allow back compatibility with the older module/library functions
#
function(geant4_global_library_target)
  cmake_parse_arguments(G4GLOBLIB
    ""
    "NAME"
    "COMPONENTS"
    ${ARGN}
    )
  __geant4_assert_no_unparsed_arguments(G4GLOBLIB geant4_global_library_target)

  # Because components are sources.cmake files, must know currently defined modules
  # so we can pick up the newly defined ones
  geant4_get_modules(__oldmodules)

  # Load components
  foreach(__comp ${G4GLOBLIB_COMPONENTS})
    include(${__comp})
  endforeach()
  # Reset directory scope include dirs so we enforce usage requirements
  set_directory_properties(PROPERTIES INCLUDE_DIRECTORIES "")

  # List modules now defined, and filter out old from new
  geant4_get_modules(__newmodules)

  if(__oldmodules)
    list(REMOVE_ITEM __newmodules ${__oldmodules})
  endif()

  # Old function allowed optional NAME argument, in which case it should
  # be the first element in the module list
  if(NOT G4GLOBLIB_NAME)
    list(GET __newmodules 0 G4GLOBLIB_NAME)
  endif()

  # Some compile definitions are still transported via directory level
  # "add_definitions" calls at the site of the geant4_global_library call
  # These, if they exist, are equivalent to PRIVATE level compile defs.
  get_directory_property(__local_compile_defs COMPILE_DEFINITIONS)
  foreach(__module ${__newmodules})
    geant4_module_compile_definitions(${__module} PRIVATE ${__local_compile_defs})
  endforeach()

  # Compose the modules into the category
  geant4_add_category(${G4GLOBLIB_NAME} MODULES ${__newmodules})
endfunction()

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: geant4_library_target
#
#   .. code-block::
#
#     geant4_library_target(NAME <name>
#                           SOURCES source1 [source2 ...]
#                           GEANT4_LINK_LIBRARIES lib1 [lib2 ...]
#                           LINK_LIBRARIES lib1 [lib2 ...])
#
# Maintained for building internal G4clhep,G4expat targets because we try and
# reuse their upstream code/build layout as far as possible
#
function(geant4_library_target)
  cmake_parse_arguments(G4GLOBLIB
    ""
    "NAME"
    "SOURCES;GEANT4_LINK_LIBRARIES;LINK_LIBRARIES"
    ${ARGN}
    )
  __geant4_assert_no_unparsed_arguments(G4GLOBLIB geant4_library_target)

  # Currently a hack to get G4clhep to build, so an error if used elsewhere
  if(NOT (${G4GLOBLIB_NAME} MATCHES "G4clhep|G4expat"))
    message(FATAL_ERROR "geant4_library_target called for '${G4GLOBLIB_NAME}' in '${CMAKE_CURRENT_LIST_DIR}'")
  endif()

  if(BUILD_SHARED_LIBS)
    add_library(${G4GLOBLIB_NAME} SHARED ${G4GLOBLIB_SOURCES})
    add_library(Geant4::${G4GLOBLIB_NAME} ALIAS ${G4GLOBLIB_NAME})
    target_compile_features(${G4GLOBLIB_NAME} PUBLIC ${GEANT4_TARGET_COMPILE_FEATURES})
    target_compile_definitions(${G4GLOBLIB_NAME} PUBLIC G4LIB_BUILD_DLL)
    target_include_directories(${G4GLOBLIB_NAME}
      PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/include>
    )
    set_target_properties(${G4GLOBLIB_NAME} PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)

    install(TARGETS ${G4GLOBLIB_NAME}
      EXPORT Geant4LibraryDepends
      RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime
      LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Runtime
      ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development
      INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME})
  endif()

  if(BUILD_STATIC_LIBS)
    add_library(${G4GLOBLIB_NAME}-static STATIC ${G4GLOBLIB_SOURCES})
    add_library(Geant4::${G4GLOBLIB_NAME}-static ALIAS ${G4GLOBLIB_NAME}-static)
    target_compile_features(${G4GLOBLIB_NAME}-static PUBLIC ${GEANT4_TARGET_COMPILE_FEATURES})
    target_include_directories(${G4GLOBLIB_NAME}-static
      PUBLIC $<BUILD_INTERFACE:${CMAKE_CURRENT_LIST_DIR}/include>
    )

    if(NOT WIN32)
      set_target_properties(${G4GLOBLIB_NAME}-static PROPERTIES OUTPUT_NAME ${G4GLOBLIB_NAME})
    endif()

    install(TARGETS ${G4GLOBLIB_NAME}-static
      EXPORT Geant4LibraryDepends
      RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR} COMPONENT Runtime
      LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Runtime
      ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR} COMPONENT Development
      INCLUDES DESTINATION ${CMAKE_INSTALL_INCLUDEDIR}/${PROJECT_NAME})
  endif()

  # Needs to be in defined category list for static/shared to be linked correctly.
  set_property(GLOBAL APPEND PROPERTY GEANT4_DEFINED_CATEGORIES ${G4GLOBLIB_NAME})
endfunction()

#-----------------------------------------------------------------------
# .rst:
# .. cmake:command:: geant4_add_compile_definitions
#
#   .. code-block:: cmake
#
#     geant4_add_compile_definitions(SOURCES <source1> ... <sourceN>
#                                    COMPILE_DEFINITIONS <def1> ... <defN>)
#
# Add extra compile definitions to a specific list of sources
# in the current module. Macroized to handle the need to specify absolute paths.
# and *must* be called at the same level as geant4_define_module
#
macro(geant4_add_compile_definitions)
  cmake_parse_arguments(G4ADDDEF
    ""
    ""
    "SOURCES;COMPILE_DEFINITIONS"
    ${ARGN}
    )
  __geant4_assert_no_unparsed_arguments(G4ADDDEF geant4_add_compile_definitions)

  # We assume that the sources have been added at the level of a
  # a sources.cmake, so are inside the src subdir of the sources.cmake
  get_filename_component(_ACD_BASE_PATH ${CMAKE_CURRENT_LIST_FILE} PATH)

  # Now for each file, add the definitions
  foreach(_acd_source ${G4ADDDEF_SOURCES})
    # Extract any existing compile definitions
    get_source_file_property(
      _acd_existing_properties
      ${_ACD_BASE_PATH}/src/${_acd_source}
      COMPILE_DEFINITIONS)

    if(_acd_existing_properties)
      set(_acd_new_defs ${_acd_existing_properties}
        ${G4ADDDEF_COMPILE_DEFINITIONS})
    else()
      set(_acd_new_defs ${G4ADDDEF_COMPILE_DEFINITIONS})
    endif()

    # quote compile defs because this must epand to space separated list
    set_source_files_properties(${_ACD_BASE_PATH}/src/${_acd_source}
      PROPERTIES COMPILE_DEFINITIONS "${_acd_new_defs}")
  endforeach()
endmacro()


#-----------------------------------------------------------------------
#.rst:
# Internal Helper Commands
# ^^^^^^^^^^^^^^^^^^^^^^^^
#
# These macros and functions are for use in the implementation of the
# module and library functions. They should never be used directly
# in developer-level scripts.

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: __geant4_assert_no_unparsed_arguments
#
#  .. code-block:: cmake
#
#    __geant4_assert_no_unparsed_arguments(<prefix> <function>)
#
#  Emit a ``FATAL_ERROR`` if ``<prefix>_UNPARSED_ARGUMENTS`` is non-empty
#  in ``<function>``
#
#  This is a macro intended for use in G4DeveloperAPI functions that cannot
#  have unparsed arguments to validate their input.
#
#  From CMake 3.17, the ``<function>`` argument is no longer required and
#  ``CMAKE_CURRENT_FUNCTION`` can be used
#
macro(__geant4_assert_no_unparsed_arguments _prefix _function)
  if(${_prefix}_UNPARSED_ARGUMENTS)
    message(FATAL_ERROR "${_function} called with unparsed arguments: '${${_prefix}_UNPARSED_ARGUMENTS}'")
  endif()
endmacro()

#-----------------------------------------------------------------------
#.rst:
# .. cmake:command:: __geant4_module_assert_exists
#
#  .. code-block:: cmake
#
#    __geant4_module_assert_exists(<name>)
#
#  Emit a ``FATAL_ERROR`` if the module ``<name>`` is not defined.
#
#  This is a macro intended for use in G4DeveloperAPI functions when
#  the existence of a module is required for further processing
#
macro(__geant4_module_assert_exists _module)
  geant4_has_module(__geant4_module_assert_exists_tmp ${_module})
  if(NOT __geant4_module_assert_exists_tmp)
    message(FATAL_ERROR "Geant4 module '${_module}' has not been created")
  endif()
endmacro()

#.rst:
# .. cmake:command:: __geant4_module_assert_not_exists
#
#  .. code-block:: cmake
#
#    __geant4_module_assert_not_exists(<name>)
#
#  Emit a ``FATAL_ERROR`` if the module ``<name>`` is defined
#
#  This is a macro intended for use in G4DeveloperAPI functions when
#  the non-existence of a module is required for further processing
#
macro(__geant4_module_assert_not_exists _module)
  geant4_has_module(__geant4_module_assert_not_exists_tmp ${_module})
  if(__geant4_module_assert_not_exists_tmp)
    geant4_get_module_property(__previous_cmake_list ${_module} CMAKE_LIST_FILE)
    message(FATAL_ERROR "Geant4 module '${_module}' has already been created by call in '${__previous_cmake_list}'")
  endif()
endmacro()

#.rst:
# .. cmake:command:: __geant4_module_validate_property
#
#  .. code-block:: cmake
#
#    __geant4_module_validate_property(<property>)
#
#  Emit a ``FATAL_ERROR`` if the ``<property>`` is not one of the valid
#  properties for a module:
#
#  This is used internally by the property get/set functions.
#
function(__geant4_module_validate_property _property)
  if(NOT (${_property} MATCHES "PUBLIC_HEADERS|PRIVATE_HEADERS|SOURCES|PRIVATE_COMPILE_DEFINITIONS|PUBLIC_COMPILE_DEFINITIONS|INTERFACE_COMPILE_DEFINITIONS|PRIVATE_INCLUDE_DIRECTORIES|PUBLIC_INCLUDE_DIRECTORIES|INTERFACE_INCLUDE_DIRECTORIES|PRIVATE_LINK_LIBRARIES|PUBLIC_LINK_LIBRARIES|INTERFACE_LINK_LIBRARIES|PARENT_TARGET|CMAKE_LIST_FILE|GLOBAL_DEPENDENCIES"))
    message(FATAL_ERROR "Undefined property '${_property}'")
  endif()
endfunction()


#.rst:
# .. cmake:command:: __geant4_add_library
#
#  .. code-block:: cmake
#
#    __geant4_add_library(<libraryname> <mode>)
#
#  Compose an actual CMake library target
#
#  This is used internally by the ``geant4_compose_targets`` command.
#
function(__geant4_add_library _name _type)
  # TEMP HACK: G4clhep/G4expat/G4ptl are a special cases, and build is handled separately
  if(_name MATCHES "G4clhep|G4expat|G4ptl")
    return()
  endif()

  if(NOT (${_type} MATCHES "SHARED|STATIC"))
    message(FATAL_ERROR "Invalid library type '${_type}'")
  endif()

  # Get targets
  get_property(__g4definedlibraries GLOBAL PROPERTY GEANT4_DEFINED_CATEGORIES)

  set(_target_name ${_name})
  if(_type STREQUAL "STATIC")
    set(_target_name ${_name}-static)
  endif()

  # - General target creation/properties
  add_library(${_target_name} ${_type} "")
  # Alias for transparent use with imported targets
  add_library(Geant4::${_target_name} ALIAS ${_target_name})
  target_compile_features(${_target_name} PUBLIC ${GEANT4_TARGET_COMPILE_FEATURES})

  if(_type STREQUAL "SHARED")
    # G4LIB_BUILD_DLL is public as despite the name it indicates the shared/archive mode
    # and clients must apply it when linking to the shared libs. The global
    # category handles the exact import/export statements
    target_compile_definitions(${_target_name} PUBLIC G4LIB_BUILD_DLL)
    set_target_properties(${_target_name} PROPERTIES WINDOWS_EXPORT_ALL_SYMBOLS ON)

    # MacOS
    # Use '@rpath' in install names of libraries on macOS to provide relocatibility
    # Add '@loader_path' to INSTALL_RPATH on macOS so that Geant4
    # libraries self-locate each other whilst remaining relocatable
    set_target_properties(${_target_name} PROPERTIES MACOSX_RPATH 1)
    if(APPLE)
      set_property(TARGET ${G4LIBTARGET_NAME} APPEND PROPERTY INSTALL_RPATH "@loader_path")
    endif()
  endif()

  if((_type STREQUAL "STATIC") AND NOT WIN32)
    set_target_properties(${_target_name} PROPERTIES OUTPUT_NAME ${_name})
  endif()

  get_property(__g4modules GLOBAL PROPERTY GEANT4_CATEGORIES_${_name}_MODULES)
  foreach(__g4mod ${__g4modules})
    # - Process sources...
    geant4_get_module_property(_headers ${__g4mod} PUBLIC_HEADERS)
    geant4_get_module_property(_srcs ${__g4mod} SOURCES)
    geant4_get_module_property(_cmakescript ${__g4mod} CMAKE_LIST_FILE)

    # - Group sources and scripts for IDEs
    # NB: Seemingly has to be done at same level we define target.
    # TODO: If lib name is same as mod name, don't group avoid extra
    # folder layer.
    source_group(${__g4mod}\\Headers FILES ${_headers})
    source_group(${__g4mod}\\Sources FILES ${_srcs})
    source_group(${__g4mod} FILES ${_cmakescript})

    # - Add sources to target - PRIVATE, because consuming targets don't need them
    target_sources(${_target_name} PRIVATE ${_headers} ${_srcs} ${_cmakescript})

    # - Process usage properties
    # Include dirs, compile definitions and libraries can be handled together
    # Important to note that these promote PUBLIC/PRIVATE/INTERFACE
    # from module level to library level. I.e. other modules in the
    # library can see each other's PRIVATE include paths/compile defs.
    # The only known way to fully wall things off is OBJECT libs,
    # but then run into issues mentioned at start - linking and
    # use in IDEs (though newer CMake versions should resolve these)
    # This "promotion" is probably correct though - interfaces are
    # at physical library level rather than module, and in Geant4
    # all files must have globally unique names (no nested headers
    # nor namespaces). Also, DLL export symbols may need this
    # behaviour (esp. ALLOC_EXPORT).
    # Only really an issue if header names/definitions aren't
    # globally (in Geant4) unique. Or if a module is moved and hasn't
    # declared its deps correctly (but then an error will occur
    # anyway, and point is that libs are linked, not modules!)
    # "Module" level really means "Source file" level, so same
    # sets of rules should apply (i.e. can't specify inc dirs
    # at source level).
    foreach(_prop IN ITEMS PRIVATE PUBLIC INTERFACE)
      geant4_get_module_property(_incdirs ${__g4mod} ${_prop}_INCLUDE_DIRECTORIES)
      target_include_directories(${_target_name} ${_prop} ${_incdirs})

      geant4_get_module_property(_defs ${__g4mod} ${_prop}_COMPILE_DEFINITIONS)
      target_compile_definitions(${_target_name} ${_prop} ${_defs})

      # Target linking requires additional processing to resolve
      geant4_get_module_property(_linklibs ${__g4mod} ${_prop}_LINK_LIBRARIES)
      geant4_resolve_link_libraries(_linklibs)

      # Remove self-linking
      if(_linklibs)
        list(REMOVE_ITEM _linklibs ${_name})
      endif()

      # Filter list for internal static targets
      if(_type STREQUAL "STATIC")
        set(_g4linklibs )
        foreach(_linklib ${_linklibs})
          # If the linklib is a G4Library, change name to "name-static"
          list(FIND __g4definedlibraries ${_linklib} _isg4lib)
          if(_isg4lib GREATER -1)
            list(APPEND _g4linklibs "${_linklib}-static")
          else()
             list(APPEND _g4linklibs "${_linklib}")
          endif()
        endforeach()
        set(_linklibs ${_g4linklibs})
      endif()

      target_link_libraries(${_target_name} ${_prop} ${_linklibs})
    endforeach()

    # Temp workaround for modules needing Qt. We use AUTOMOC, but can't yet set
    # it on a per module basis. However, only have four modules that require
    # moc-ing, so hard code for now.
    # TODO: likely need an additional "module target properties" to hold things
    # that can be passed to set_target_properties
    if(__g4mod MATCHES "G4UIbasic|G4OpenGL|G4OpenInventor|G4ToolsSG" AND GEANT4_USE_QT)
      set_target_properties(${_target_name} PROPERTIES AUTOMOC ON)
    endif()
  endforeach()

  # - Postprocess target properties to remove duplicates
  # NB: This makes the assumption that there is no order dependence here (and any is considered a bug!)
  #     CMake will handle static link ordering internally
  foreach(_link_prop IN ITEMS LINK_LIBRARIES INTERFACE_LINK_LIBRARIES INCLUDE_DIRECTORIES INTERFACE_INCLUDE_DIRECTORIES COMPILE_DEFINITIONS INTERFACE_COMPILE_DEFINITIONS)
    get_target_property(__g4lib_link_libs ${_target_name} ${_link_prop})
    if(__g4lib_link_libs)
      list(SORT __g4lib_link_libs)
      list(REMOVE_DUPLICATES __g4lib_link_libs)
      set_property(TARGET ${_target_name} PROPERTY ${_link_prop} ${__g4lib_link_libs})
    endif()
  endforeach()
endfunction()
