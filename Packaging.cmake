
find_package(${QT} COMPONENTS Core REQUIRED)
get_target_property(qmake_executable ${QT}::qmake IMPORTED_LOCATION)
get_filename_component(_qt_bin_dir "${qmake_executable}" DIRECTORY)
find_program(WINDEPLOYQT_EXECUTABLE windeployqt HINTS "${_qt_bin_dir}")
find_program(LINUXDEPLOY_EXECUTABLE linuxdeploy linuxdeploy-x86_64.AppImage HINTS "${_qt_bin_dir}")
find_program(MACDEPLOYQT_EXECUTABLE macdeployqt HINTS "${_qt_bin_dir}")
find_program(MACDEPLOYQTFIX_EXECUTABLE macdeployqtfix.py HINTS "${_qt_bin_dir}")
find_package(Python)

set(CPACK_IFW_ROOT $ENV{HOME}/Qt/QtIFW-3.0.6/ CACHE PATH "Qt Installer Framework installation base path")
find_program(BINARYCREATOR_EXECUTABLE binarycreator HINTS "${_qt_bin_dir}" ${CPACK_IFW_ROOT}/bin)

mark_as_advanced(WINDEPLOYQT_EXECUTABLE LINUXDEPLOY_EXECUTABLE MACDEPLOYQT_EXECUTABLE)

function(linuxdeployqt destdir desktopfile)
    # creating AppDir
    add_custom_command(TARGET bundle PRE_BUILD
                       COMMAND "${CMAKE_MAKE_PROGRAM}" DESTDIR=${destdir} install
                       WORKING_DIRECTORY ${CMAKE_BINARY_DIR})
    # packaging AppImage
    add_custom_command(TARGET bundle POST_BUILD
                       COMMAND env QMAKE=${qmake_executable} "${LINUXDEPLOY_EXECUTABLE}" --appdir=${destdir} --plugin=qt --output=appimage -e ${CMAKE_BINARY_DIR}/${target} -d ${destdir}/${CMAKE_INSTALL_PREFIX}/${desktopfile}
                       WORKING_DIRECTORY ${CMAKE_BINARY_DIR})
endfunction()

function(windeployqt target)

    # Bundle Library Files
    if(CMAKE_BUILD_TYPE_UPPER STREQUAL "DEBUG")
        set(WINDEPLOYQT_ARGS --debug)
    else()
        set(WINDEPLOYQT_ARGS --release)
    endif()

    add_custom_command(TARGET ${target} POST_BUILD
                       COMMAND "${CMAKE_COMMAND}" -E remove_directory "${CMAKE_CURRENT_BINARY_DIR}/winqt/"
                       COMMAND "${CMAKE_COMMAND}" -E
                               env PATH="${_qt_bin_dir}" "${WINDEPLOYQT_EXECUTABLE}"
                               ${WINDEPLOYQT_ARGS}
                               --verbose 0
                               --no-compiler-runtime
                               --no-angle
                               --no-opengl-sw
                               --dir "${CMAKE_CURRENT_BINARY_DIR}/winqt/"
                               $<TARGET_FILE:${target}>
                       COMMENT "Deploying Qt..."
    )
    install(DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/winqt/" DESTINATION bin)
    set(CMAKE_INSTALL_UCRT_LIBRARIES TRUE)
    include(InstallRequiredSystemLibraries)
endfunction()

function(macdeployqt bundle targetdir _PACKAGER)
    file(GENERATE OUTPUT ${CMAKE_BINARY_DIR}/CPackMacDeployQt-${_PACKAGER}.cmake
                  CONTENT "execute_process(COMMAND \"${MACDEPLOYQT_EXECUTABLE}\" \"${CPACK_PACKAGE_DIRECTORY}/_CPack_Packages/Darwin/${_PACKAGER}/${targetdir}/${bundle}\" -always-overwrite)")
    install(SCRIPT ${CMAKE_BINARY_DIR}/CPackMacDeployQt-${_PACKAGER}.cmake COMPONENT Runtime)
    include(InstallRequiredSystemLibraries)
endfunction()

set(CPACK_PACKAGE_VENDOR "vitark")
set(CPACK_PACKAGE_NAME "${PROJECT_NAME}")
set(CPACK_PACKAGE_CONTACT "Vitalii Arkusha <vitalik.arkusha@gmail.com>")
set(CPACK_PACKAGE_AUTHORS "Vitalii Arkusha")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "${PROJECT_DESCRIPTION}")
set(CPACK_PACKAGE_DESCRIPTION_FILE "${CMAKE_SOURCE_DIR}/README.md")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_SOURCE_DIR}/LICENSE")
set(CPACK_PACKAGE_VERSION_MAJOR ${PROJECT_VERSION_MAJOR})
set(CPACK_PACKAGE_VERSION_MINOR ${PROJECT_VERSION_MINOR})
set(CPACK_PACKAGE_VERSION_PATCH ${PROJECT_VERSION_PATCH})

set(CPACK_PACKAGE_INSTALL_DIRECTORY "${PROJECT_NAME}")
set(CPACK_PACKAGE_DIRECTORY "${CMAKE_BINARY_DIR}")

# set human names to exetuables
set(CPACK_PACKAGE_EXECUTABLES "${PROJECT_NAME}" "PS Management")
set(CPACK_CREATE_DESKTOP_LINKS "${PROJECT_NAME}")
set(CPACK_STRIP_FILES TRUE)

#------------------------------------------------------------------------------
# include CPack, so we get target for packages
set(CPACK_OUTPUT_CONFIG_FILE "${CMAKE_BINARY_DIR}/BundleConfig.cmake")

add_custom_target(bundle
                  COMMAND ${CMAKE_CPACK_COMMAND} "--config" "${CMAKE_BINARY_DIR}/BundleConfig.cmake"
                  COMMENT "Running CPACK. Please wait..."
                  DEPENDS ${PROJECT_NAME})
set(CPACK_GENERATOR)

# Qt IFW packaging framework
if(BINARYCREATOR_EXECUTABLE)
    list(APPEND CPACK_GENERATOR IFW)
    message(STATUS "   + Qt Installer Framework               YES ")
else()
    message(STATUS "   + Qt Installer Framework                NO ")
endif()

if(WIN32 AND NOT UNIX)
    #--------------------------------------------------------------------------
    # Windows specific
    list(APPEND CPACK_GENERATOR ZIP)
    message(STATUS "Package generation - Windows")
    message(STATUS "   + ZIP                                  YES ")
    
    set(PACKAGE_ICON "${CMAKE_SOURCE_DIR}/src/assets/power-supply.ico")

    # NSIS windows installer
    find_program(NSIS_PATH nsis PATH_SUFFIXES nsis)
    if(NSIS_PATH)
        list(APPEND CPACK_GENERATOR NSIS)
        message(STATUS "   + NSIS                                 YES ")

        set(CPACK_NSIS_DISPLAY_NAME ${CPACK_PACKAGE_NAME})
        # Icon of the installer
        file(TO_CMAKE_PATH "${PACKAGE_ICON}" CPACK_NSIS_MUI_ICON)
        file(TO_CMAKE_PATH "${PACKAGE_ICON}" CPACK_NSIS_MUI_HEADERIMAGE_BITMAP)
        set(CPACK_NSIS_CONTACT "${CPACK_PACKAGE_AUTHORS}")
        set(CPACK_NSIS_MODIFY_PATH ON)
    else()
        message(STATUS "   + NSIS                                 NO ")
    endif()

    # NuGet package
    # find_program(NUGET_EXECUTABLE nuget)
    set(NUGET_EXECUTABLE OFF)
    if(NUGET_EXECUTABLE)
        list(APPEND CPACK_GENERATOR NuGET)
        message(STATUS "   + NuGET                               YES ")
        set(CPACK_NUGET_PACKAGE_NAME "${PROJECT_NAME}")
	set(CPACK_NUGET_PACKAGE_VERSION "${PROJECT_VERSION}")
	set(CPACK_NUGET_PACKAGE_DESCRIPTION "${PROJECT_DESCRIPTION}")
	set(CPACK_NUGET_PACKAGE_AUTHORS "${CPACK_PACKAGE_CONTACT}")
    else()
        message(STATUS "   + NuGET                                NO ")
    endif()

    windeployqt(${PROJECT_NAME})

elseif(APPLE)
    #--------------------------------------------------------------------------
    # Apple specific
    message(STATUS "Package generation - Mac OS X")
    message(STATUS "   + TBZ2                                 YES ")

    list(APPEND CPACK_GENERATOR TBZ2)
    set(CPACK_PACKAGE_ICON ${CMAKE_SOURCE_DIR}/src/assets/power-supply.icns)
    set(CMAKE_INSTALL_RPATH "@executable_path/../Frameworks")
    macdeployqt("${PROJECT_NAME}.app" "${PROJECT_NAME}-${PROJECT_VERSION}-Darwin" "TBZ2")

    # XXX: not working settings for bundle and dragndrop generator
    set(CPACK_BUNDLE_NAME "${PROJECT_NAME}" )
    set(CPACK_BUNDLE_PLIST "${CMAKE_BINARY_DIR}/Info.plist")
    set(CPACK_BUNDLE_ICON ${CPACK_PACKAGE_ICON})
    set(CPACK_DMG_VOLUME_NAME "${PROJECT_NAME}")
    set(CPACK_DMG_FORMAT "UDBZ")
    set(CPACK_DMG_BACKGROUND_IMAGE "${CMAKE_SOURCE_DIR}/src/assets/power-supply_64.png")

    if(CMAKE_VERSION VERSION_GREATER_EQUAL 3.13)
        set(CPACK_GENERATOR "External;${CPACK_GENERATOR}")
        message(STATUS "   + macdeployqt -dmg                     YES ")
        configure_file(${CMAKE_CURRENT_SOURCE_DIR}/CPackMacDeployQt.cmake.in "${CMAKE_BINARY_DIR}/CPackExternal.cmake")
        set(CPACK_EXTERNAL_PACKAGE_SCRIPT "${CMAKE_BINARY_DIR}/CPackExternal.cmake")
    endif()

else()
    #-----------------------------------------------------------------------------
    # Linux specific
    list(APPEND CPACK_GENERATOR TBZ2 TXZ)
    message(STATUS "Package generation - UNIX")
    message(STATUS "   + TBZ2                                 YES ")
    message(STATUS "   + TXZ                                  YES ")

    find_program(RPMBUILD_PATH rpmbuild)
    if(RPMBUILD_PATH)
        message(STATUS "   + RPM                                  YES ")
        set(CPACK_GENERATOR "${CPACK_GENERATOR};RPM")
        set(CPACK_RPM_PACKAGE_LICENSE "MIT")
    else()
        message(STATUS "   + RPM                                  NO ")
    endif()

    list(APPEND CPACK_GENERATOR DEB)
    message(STATUS "   + DEB                                  YES ")
    set(CPACK_DEBIAN_PACKAGE_ARCHITECTURE "amd64")
    set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
    set(CPACK_DEBIAN_PACKAGE_CONTROL_STRICT_PERMISSION TRUE)
    set(CPACK_DEBIAN_PACKAGE_HOMEPAGE "${PROJECT_URL}")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "${CPACK_PACKAGE_AUTHORS}")
    set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)  # ON When build with libraries only from debian packages. Package dpkg-dev is required to be installed

    if(LINUXDEPLOY_EXECUTABLE)
        message(STATUS "   + AppImage                             YES ")
        if(CMAKE_VERSION VERSION_LESS 3.13)
            linuxdeployqt("${CPACK_PACKAGE_DIRECTORY}/_CPack_Packages/Linux/AppImage" "share/applications/ps-management.desktop")
        else()
            set(CPACK_GENERATOR "External;${CPACK_GENERATOR}")
            configure_file(${CMAKE_CURRENT_SOURCE_DIR}/CPackLinuxDeployQt.cmake.in "${CMAKE_BINARY_DIR}/CPackExternal.cmake")
            set(CPACK_EXTERNAL_PACKAGE_SCRIPT "${CMAKE_BINARY_DIR}/CPackExternal.cmake")
        endif()
    else()
        message(STATUS "   + AppImage                              NO ")
    endif()

    set(CPACK_PACKAGE_ICON "${CMAKE_SOURCE_DIR}/src/assets/ps-management.png")
endif()

include(CPack)
