!
! GIMIC - a pretty advanced 'Hello World!' program.
!

#include "config.h"

program gimic
    use globals_m  
    use settings_m
    use teletype_m
    use basis_class
    use timer_m
    use magnet_m
    use parallel_m
    implicit none 

    character(BUFLEN) :: buf
    type(molecule_t) :: mol
    type(getkw_t) :: input
    
    call new_getkw(input)
    call set_debug_level(3)

    mpi_rank = init_mpi(settings%is_mpirun)

    call program_header
    call initialize()
    call dispatcher()
    call finalize()

    call stockas_klocka()
    call msg_out('Hello World! (tm)')
    call program_footer()
    
    if (bert_is_evil) then
        call msg_error('Bert is evil, and your results are wicked.')
        call nl
    end if

contains
    subroutine initialize()
        integer(I4) :: i, hostnm, rank, ierr
        integer(I4) :: chdir, system
        character(BUFLEN) :: title, fdate, sys
        real(DP), dimension(3) :: center, magnet

        logical :: screen

        call getkw(input, 'debug', debug_level)
        call set_debug_level(debug_level)

        call getkw(input, 'title', settings%title)
        call getkw(input, 'basis', settings%basis)
        call getkw(input, 'xdens', settings%xdens)
        call getkw(input, 'density', settings%density)
        call getkw(input, 'magnet_axis', settings%magnet_axis)
        call getkw(input, 'magnet', settings%magnet)
        call getkw(input, 'openshell', settings%is_uhf)
        call getkw(input, 'dryrun', settings%dryrun)
        call getkw(input, 'calc', settings%calc)
        call getkw(input, 'xdens', settings%xdens)
        call getkw(input, 'density', settings%density)
        call getkw(input, 'mofile', settings%mofile)
        call getkw(input, 'mos', settings%morange)

        settings%use_spherical=.false.
        settings%screen_thrs = SCREEN_THRS
        call getkw(input, 'Advanced.spherical', settings%use_spherical)
        call getkw(input, 'Advanced.GIAO', settings%use_giao)
        call getkw(input, 'Advanced.diamag', settings%use_diamag)
        call getkw(input, 'Advanced.paramag',settings%use_paramag)
        call getkw(input, 'Advanced.screening', settings%use_screening)
        call getkw(input, 'Advanced.screening_thrs', settings%screen_thrs)
        call getkw(input, 'Advanced.lip_order', settings%lip_order)

        ierr=hostnm(sys)
        if (mpi_rank == 0) then
            write(str_g, '(a,i3,a,a)') 'MPI master', rank,' on ', trim(sys)
            call msg_debug(str_g,2)
        else
            call set_teletype_unit(DEVNULL)
            write(str_g, '(a,i3,a,a)') 'MPI slave', rank,' on ', trim(sys)
            call msg_debug(str_g,2)
        end if

        call msg_out(fdate())
        
        call msg_out(' TITLE: '// trim(settings%title))
        call nl
        
        if (.not.settings%use_giao) then
            call msg_info('GIAOs not used!')
            call nl
        end if

        if (.not.settings%use_diamag) then
            call msg_info( 'Diamagnetic contributions not calculated!')
            call nl
        end if
        if (.not.settings%use_paramag) then
            call msg_info( 'Paramagnetic contributions not calculated!')
            call nl
        end if
        if ((.not.settings%use_diamag).and.(.not.settings%use_paramag)) then
            call msg_out( '    ...this does not make sense...')
            call nl
            call msg_critical( '    PLEASE SEEK PROFESSIONAL HELP, ASAP!  ')
            call nl
            stop
        end if
    end subroutine

    subroutine finalize()
        call del_basis(mol)
        call stop_mpi()
        call del_getkw(input)
    end subroutine

    subroutine dispatcher
        use globals_m
        use settings_m
        use cao2sao_class
        use basis_class
        use dens_class
        use jtensor_class
        use jfield_class
        use caos_m
        use grid_class
        use gaussint_m
        use integral_class
        use divj_field_class
        use edens_field_class

        type(jfield_t) :: jf
        type(grid_t) :: grid
        type(jtensor_t) :: jt
        type(dens_t) :: xdens, modens
        type(divj_field_t) :: dj
        type(edens_field_t) :: ed
        type(integral_t) :: it
        type(cao2sao_t) :: c2s

        integer(I4) :: i,j

        character(80) :: fname, mofile
        integer, dimension(2) :: morange
        real(DP), dimension(3) :: magnet

        if (settings%use_screening) then
            call new_basis(mol, settings%basis, settings%screen_thrs)
        else
            call new_basis(mol, settings%basis, -1.d0)
        end if

        if (settings%use_spherical) then
            call new_c2sop(c2s,mol)
            call set_c2sop(mol, c2s)
        end if

        call setup_grid(grid)

        if (settings%is_uhf) then
            call msg_info('Open-shell calculation')
        else
            call msg_info('Closed-shell calculation')
        end if
        call nl

        if (settings%dryrun) then
            call msg_note('Dry run, not calculating...')
            call nl
        end if
        
        if (settings%calc(1:5) == 'cdens') then 
            call run_cdens()
        else if (settings%calc(1:8) == 'integral') then 
            call run_integral()
        else if (settings%calc(1:4) == 'divj') then 
            call run_divj()
        else if (settings%calc(1:5) == 'edens') then 
            call run_edens()
        else
            call msg_error('gimic(): Unknown operation!')
        end if
    end do

    if (settings%use_spherical) then
        call del_c2sop(c2s)
    end if
    call del_grid(grid)
    end subroutine

    subroutine run_cdens
        call msg_out('Calculating current density')
        call msg_out('*****************************************')
        call new_dens(xdens, mol)
        call new_jtensor(jt,mol,xdens)
        call read_dens(xdens, fname)
        call get_magnet(grid, magnet)
        call new_jfield(jf, jt, grid, magnet)
        if (settings%dryrun) cycle
        call jfield(jf)
        ! Contract the tensors with B
        if (mpi_rank == 0) then
            call jvectors(jf)
            call jvector_plot(jf)
        end if
        call del_jfield(jf)
        call del_dens(xdens)
        call del_jtensor(jt)
    end subroutine

    subroutine run_integral
        call msg_out('Integrating current density')
        call msg_out('*****************************************')
        call new_integral(it, jt, jf, grid)
        if (settings%dryrun) cycle
        call int_s_direct(it)
        call nl
        call msg_note('Integrating |J|')
        call int_mod_direct(it)
        call msg_note('Integrating current tensor')
        call int_t_direct(it)  ! tensor integral
        !                    call write_integral(it)
        call del_integral(it)
    end subroutine

    subroutine run_divj
        call msg_out('Calculating divergence')
        call msg_out('*****************************************')
        call new_divj_field(dj, grid, magnet)
        if (settings%dryrun) cycle
        call divj_field(dj)
        if (mpi_rank == 0) then 
            call divj_plot(dj, 'divj')
        end if
        call del_divj_field(dj)
    end subroutine
    
    subroutine run_edens
        call msg_out('Calculating charge density')
        call msg_out('*****************************************')
        call new_dens(modens, mol, modens_p)
        call read_modens(modens, fname, mofile, morange)
        call new_edens_field(ed, mol, modens, grid, fname)
        if (settings%dryrun) cycle
        call edens_field(ed)
        if (mpi_rank == 0) then 
            call edens_plot(ed, "edens")
        end if
        call del_edens_field(ed)
        call del_dens(modens)
    end subroutine
    
    subroutine setup_grid(grid)
        use grid_class
        type(grid_t) :: grid
        logical :: p 
        integer(I4) :: i
        real(DP), dimension(3) :: center
        
        p=.false. 

        call new_grid(grid, input, mol)
        call grid_center(grid, center)
        if (mpi_rank == 0) then
            call plot_grid_xyz(grid, 'grid.xyz',  mol)
        end if
    end subroutine


    subroutine program_header
        integer(I4) :: i,j,sz
        integer(I4), dimension(3) :: iti
        integer(I4), dimension(:), allocatable :: seed

        call random_seed(size=sz)
        allocate(seed(sz))
        call random_seed(get=seed)
        call itime(iti)
        j=sum(iti)
        do i=1,sz
            seed(i)=seed(i)*j
        end do
        call random_seed(put=seed)
        deallocate(seed)

call nl
call msg_out('****************************************************************')
call msg_out('***                                                          ***')
call msg_out('***           GIMIC '// PROJECT_VERSION // &
                                      '                                    ***')
call msg_out('***              Written by Jonas Juselius                   ***')
call msg_out('***                                                          ***')
call msg_out('***  This software is copyright (c) 2003-2011 by             ***')
call msg_out('***  Jonas Juselius,  University of Tromsø.                  ***')
call msg_out('***                                                          ***')
call msg_out('***  You are free to distribute this software under the      ***')
call msg_out('***  terms of the GNU General Public License                 ***')
call msg_out('***                                                          ***')
call msg_out('***  A Pretty Advanced ''Hello World!'' Program              ***')
call msg_out('****************************************************************')
call nl
    end subroutine

    subroutine program_footer
        real(DP) :: rnd
        character(*), dimension(5), parameter :: raboof=(/ &
            'GIMIC - Grossly Irrelevant Magnetically Incuced Currents', &
            'GIMIC - Gone Interrailing, My Inspiration Croaked       ', &
            'GIMIC - Galenskap I Miniatyr, Ingen Censur              ', &
            'GIMIC - Gone Insane, My Indifferent Cosmos              ', &
            'GIMIC - Give Idiots More Ice-Coffee                     '/)

        call random_number(rnd)
        call nl
        !call msg_out(raboof(nint(rnd*5.d0)))
        call msg_out('done.')
        call nl
    end subroutine

end program 

! vim:et:sw=4:ts=4
