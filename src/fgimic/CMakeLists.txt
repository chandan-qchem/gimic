
add_executable(gimic.bin 
    gimic.f90
    getkw.f90
    integral.f90
    cubeplot.f90
    vtkplot.f90
    magnet.f90
    grid.f90
    jfield.f90
    divj_field.f90
    parallel.f90
    edens_field.f90
    )
target_link_libraries(gimic.bin gimic2)

configure_file(gimic.py.in gimic.py)

install(FILES __init__.py ${CMAKE_CURRENT_BINARY_DIR}/gimic.py getkw.py 
    DESTINATION ${PYTHON_SITE_INSTALL_DIR}/fgimic
    )

install(TARGETS gimic.bin
    DESTINATION bin
    )

if (ENABLE_CFOUR)
    find_package(CFour)
    if (CFOUR_FOUND)
        link_directories(${CFOUR_LIBRARY_DIR})
        add_executable(xcpdens 
            xcpdens.f90
            )
        target_link_libraries(xcpdens libr)

        install(TARGETS xcpdens
            DESTINATION bin
            )
    endif()
endif()

