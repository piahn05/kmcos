!  This file was generated by kmcos (kinetic Monte Carlo of Systems)
!  written by Max J. Hoffmann mjhoffmann@gmail.com (C) 2009-2013.
!  The model was written by Andreas Garhammer.

!  This file is part of kmcos.
!
!  kmcos is free software; you can redistribute it and/or modify
!  it under the terms of the GNU General Public License as published by
!  the Free Software Foundation; either version 2 of the License, or
!  (at your option) any later version.
!
!  kmcos is distributed in the hope that it will be useful,
!  but WITHOUT ANY WARRANTY; without even the implied warranty of
!  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!  GNU General Public License for more details.
!
!  You should have received a copy of the GNU General Public License
!  along with kmcos; if not, write to the Free Software
!  Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301
!  USA
!****h* kmcos/proclist
! FUNCTION
!    Implements the kMC process list.
!
!******


module proclist
use kind_values
use base, only: &
    update_accum_rate, &
    update_integ_rate, &
    determine_procsite, &
    update_clocks, &
    avail_sites, &
    null_species, &
    increment_procstat

use lattice, only: &
    default, &
    default_a_1, &
    default_a_2, &
    default_b_1, &
    default_b_2, &
    allocate_system, &
    nr2lattice, &
    lattice2nr, &
    add_proc, &
    can_do, &
    set_rate_const, &
    replace_species, &
    del_proc, &
    reset_site, &
    system_size, &
    spuck, &
    get_species


implicit none



 ! Species constants



integer(kind=iint), parameter, public :: nr_of_species = 2
integer(kind=iint), parameter, public :: empty = 0
integer(kind=iint), parameter, public :: ion = 1
integer(kind=iint), public :: default_species = empty


! Process constants

integer(kind=iint), parameter, public :: a_1_a_2 = 1
integer(kind=iint), parameter, public :: a_1_b_1 = 2
integer(kind=iint), parameter, public :: a_1_b_2 = 3
integer(kind=iint), parameter, public :: a_2_a_1 = 4
integer(kind=iint), parameter, public :: a_2_b_1 = 5
integer(kind=iint), parameter, public :: a_2_b_2 = 6
integer(kind=iint), parameter, public :: b_1_a_1 = 7
integer(kind=iint), parameter, public :: b_1_a_2 = 8
integer(kind=iint), parameter, public :: b_1_b_2 = 9
integer(kind=iint), parameter, public :: b_2_a_1 = 10
integer(kind=iint), parameter, public :: b_2_a_2 = 11
integer(kind=iint), parameter, public :: b_2_b_1 = 12


integer(kind=iint), parameter, public :: representation_length = 11
integer(kind=iint), public :: seed_size = 33
integer(kind=iint), public :: seed ! random seed
integer(kind=iint), public, dimension(:), allocatable :: seed_arr ! random seed


integer(kind=iint), parameter, public :: nr_of_proc = 12


contains

subroutine do_kmc_steps(n)

!****f* proclist/do_kmc_steps
! FUNCTION
!    Performs ``n`` kMC step.
!    If one has to run many steps without evaluation
!    do_kmc_steps might perform a little better.
!    * first update clock
!    * then configuration sampling step
!    * last execute process
!
! ARGUMENTS
!
!    ``n`` : Number of steps to run
!******
    integer(kind=ilong), intent(in) :: n

    integer(kind=ilong) :: i
    real(kind=rsingle) :: ran_proc, ran_time, ran_site
    integer(kind=iint) :: nr_site, proc_nr

    do i = 1, n
    call random_number(ran_time)
    call random_number(ran_proc)
    call random_number(ran_site)
    call update_accum_rate
    call update_clocks(ran_time)

    call update_integ_rate
    call determine_procsite(ran_proc, ran_site, proc_nr, nr_site)
    call run_proc_nr(proc_nr, nr_site)
    enddo

end subroutine do_kmc_steps

subroutine do_kmc_step()

!****f* proclist/do_kmc_step
! FUNCTION
!    Performs exactly one kMC step.
!    *  first update clock
!    *  then configuration sampling step
!    *  last execute process
!
! ARGUMENTS
!
!    ``none``
!******
    real(kind=rsingle) :: ran_proc, ran_time, ran_site
    integer(kind=iint) :: nr_site, proc_nr

    call random_number(ran_time)
    call random_number(ran_proc)
    call random_number(ran_site)
    call update_accum_rate
    call update_clocks(ran_time)

    call update_integ_rate
    call determine_procsite(ran_proc, ran_site, proc_nr, nr_site)
    call run_proc_nr(proc_nr, nr_site)
end subroutine do_kmc_step

subroutine get_next_kmc_step(proc_nr, nr_site)

!****f* proclist/get_kmc_step
! FUNCTION
!    Determines next step without executing it.
!
! ARGUMENTS
!
!    ``none``
!******
    real(kind=rsingle) :: ran_proc, ran_time, ran_site
    integer(kind=iint), intent(out) :: nr_site, proc_nr

    call random_number(ran_time)
    call random_number(ran_proc)
    call random_number(ran_site)
    call update_accum_rate
    call determine_procsite(ran_proc, ran_time, proc_nr, nr_site)

end subroutine get_next_kmc_step

subroutine get_occupation(occupation)

!****f* proclist/get_occupation
! FUNCTION
!    Evaluate current lattice configuration and returns
!    the normalized occupation as matrix. Different species
!    run along the first axis and different sites run
!    along the second.
!
! ARGUMENTS
!
!    ``none``
!******
    ! nr_of_species = 2, spuck = 4
    real(kind=rdouble), dimension(0:1, 1:4), intent(out) :: occupation

    integer(kind=iint) :: i, j, k, nr, species

    occupation = 0

    do k = 0, system_size(3)-1
        do j = 0, system_size(2)-1
            do i = 0, system_size(1)-1
                do nr = 1, spuck
                    ! shift position by 1, so it can be accessed
                    ! more straightforwardly from f2py interface
                    species = get_species((/i,j,k,nr/))
                    if(species.ne.null_species) then
                    occupation(species, nr) = &
                        occupation(species, nr) + 1
                    endif
                end do
            end do
        end do
    end do

    occupation = occupation/real(system_size(1)*system_size(2)*system_size(3))
end subroutine get_occupation

subroutine init(input_system_size, system_name, layer, seed_in, no_banner)

!****f* proclist/init
! FUNCTION
!     Allocates the system and initializes all sites in the given
!     layer.
!
! ARGUMENTS
!
!    * ``input_system_size`` number of unit cell per axis.
!    * ``system_name`` identifier for reload file.
!    * ``layer`` initial layer.
!    * ``no_banner`` [optional] if True no copyright is issued.
!******
    integer(kind=iint), intent(in) :: layer, seed_in
    integer(kind=iint), dimension(2), intent(in) :: input_system_size

    character(len=400), intent(in) :: system_name

    logical, optional, intent(in) :: no_banner

    if (.not. no_banner) then
        print *, "+------------------------------------------------------------+"
        print *, "|                                                            |"
        print *, "| This kMC Model '2d_auto' was written by                    |"
        print *, "|                                                            |"
        print *, "|     Andreas Garhammer (andreas-garhammer@t-online.de)      |"
        print *, "|                                                            |"
        print *, "| and implemented with the help of kmcos,                    |"
        print *, "| which is distributed under GNU/GPL Version 3               |"
        print *, "| (C) Max J. Hoffmann mjhoffmann@gmail.com                   |"
        print *, "|                                                            |"
        print *, "| kmcos is distributed in the hope that it will be useful    |"
        print *, "| but WITHOUT ANY WARRANTY; without even the implied         |"
        print *, "| warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR    |"
        print *, "| PURPOSE. See the GNU General Public License for more       |"
        print *, "| details.                                                   |"
        print *, "|                                                            |"
        print *, "| If using kmcos for a publication, attribution is           |"
        print *, "| greatly appreciated.                                       |"
        print *, "| Hoffmann, M. J., Matera, S., & Reuter, K. (2014).          |"
        print *, "| kmos: A lattice kinetic Monte Carlo framework.             |"
        print *, "| Computer Physics Communications, 185(7), 2138-2150.        |"
        print *, "|                                                            |"
        print *, "| Development https://github.com/kmcos/kmcos                 |"
        print *, "| Documentation https://kmcos.readthedocs.io                 |"
        print *, "| Reference https://dx.doi.org/10.1016/j.cpc.2014.04.003     |"
        print *, "|                                                            |"
        print *, "+------------------------------------------------------------+"
        print *, ""
        print *, ""
    endif
    call allocate_system(nr_of_proc, input_system_size, system_name)
    call initialize_state(layer, seed_in)
end subroutine init

subroutine initialize_state(layer, seed_in)

!****f* proclist/initialize_state
! FUNCTION
!    Initialize all sites and book-keeping array
!    for the given layer.
!
! ARGUMENTS
!
!    * ``layer`` integer representing layer
!******
    integer(kind=iint), intent(in) :: layer, seed_in

    integer(kind=iint) :: i, j, k, nr
    ! initialize random number generator
    allocate(seed_arr(seed_size))
    seed = seed_in
    seed_arr = seed
    call random_seed(size=seed_size)
    call random_seed(put=seed_arr)
    deallocate(seed_arr)
    do k = 0, system_size(3)-1
        do j = 0, system_size(2)-1
            do i = 0, system_size(1)-1
                do nr = 1, spuck
                    call reset_site((/i, j, k, nr/), null_species)
                end do
                select case(layer)
                case (default)
                    call replace_species((/i, j, k, default_a_1/), null_species, ion)
                    call replace_species((/i, j, k, default_a_2/), null_species, ion)
                    call replace_species((/i, j, k, default_b_1/), null_species, empty)
                    call replace_species((/i, j, k, default_b_2/), null_species, empty)
                end select
            end do
        end do
    end do

    do k = 0, system_size(3)-1
        do j = 0, system_size(2)-1
            do i = 0, system_size(1)-1
                select case(layer)
                case(default)
                    call touchup_default_a_1((/i, j, k, default_a_1/))
                    call touchup_default_a_2((/i, j, k, default_a_2/))
                    call touchup_default_b_1((/i, j, k, default_b_1/))
                    call touchup_default_b_2((/i, j, k, default_b_2/))
                end select
            end do
        end do
    end do


end subroutine initialize_state

subroutine run_proc_nr(proc, nr_site)

!****f* proclist/run_proc_nr
! FUNCTION
!    Runs process ``proc`` on site ``nr_site``.
!
! ARGUMENTS
!
!    * ``proc`` integer representing the process number
!    * ``nr_site``  integer representing the site
!******
    integer(kind=iint), intent(in) :: proc
    integer(kind=iint), intent(in) :: nr_site

    integer(kind=iint), dimension(4) :: lsite

    call increment_procstat(proc)

    ! lsite = lattice_site, (vs. scalar site)
    lsite = nr2lattice(nr_site, :)

    select case(proc)
    case(a_1_a_2)
        call put_ion_default_a_2(lsite + (/0, 0, 0, default_a_2 - default_a_1/))
        call take_ion_default_a_1(lsite)

    case(a_1_b_1)
        call put_ion_default_b_1(lsite + (/0, 0, 0, default_b_1 - default_a_1/))
        call take_ion_default_a_1(lsite)

    case(a_1_b_2)
        call put_ion_default_b_2(lsite + (/0, 0, 0, default_b_2 - default_a_1/))
        call take_ion_default_a_1(lsite)

    case(a_2_a_1)
        call put_ion_default_a_1(lsite)
        call take_ion_default_a_2(lsite + (/0, 0, 0, default_a_2 - default_a_1/))

    case(a_2_b_1)
        call put_ion_default_b_1(lsite + (/0, 0, 0, default_b_1 - default_a_2/))
        call take_ion_default_a_2(lsite)

    case(a_2_b_2)
        call put_ion_default_b_2(lsite + (/0, 0, 0, default_b_2 - default_a_2/))
        call take_ion_default_a_2(lsite)

    case(b_1_a_1)
        call put_ion_default_a_1(lsite)
        call take_ion_default_b_1(lsite + (/0, 0, 0, default_b_1 - default_a_1/))

    case(b_1_a_2)
        call put_ion_default_a_2(lsite)
        call take_ion_default_b_1(lsite + (/0, 0, 0, default_b_1 - default_a_2/))

    case(b_1_b_2)
        call put_ion_default_b_2(lsite + (/0, 0, 0, default_b_2 - default_b_1/))
        call take_ion_default_b_1(lsite)

    case(b_2_a_1)
        call put_ion_default_a_1(lsite)
        call take_ion_default_b_2(lsite + (/0, 0, 0, default_b_2 - default_a_1/))

    case(b_2_a_2)
        call put_ion_default_a_2(lsite)
        call take_ion_default_b_2(lsite + (/0, 0, 0, default_b_2 - default_a_2/))

    case(b_2_b_1)
        call put_ion_default_b_1(lsite)
        call take_ion_default_b_2(lsite + (/0, 0, 0, default_b_2 - default_b_1/))

    end select

end subroutine run_proc_nr

subroutine put_ion_default_a_1(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, empty, ion)

    ! disable affected processes
    if(avail_sites(a_2_a_1, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(a_2_a_1, site)
    endif

    if(avail_sites(b_1_a_1, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(b_1_a_1, site)
    endif

    if(avail_sites(b_2_a_1, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(b_2_a_1, site)
    endif

    ! enable affected processes
    select case(get_species(site + (/0, 0, 0, default_a_2 - default_a_1/)))
    case(empty)
        call add_proc(a_1_a_2, site)
    end select

    select case(get_species(site + (/0, 0, 0, default_b_1 - default_a_1/)))
    case(empty)
        call add_proc(a_1_b_1, site)
    end select

    select case(get_species(site + (/0, 0, 0, default_b_2 - default_a_1/)))
    case(empty)
        call add_proc(a_1_b_2, site)
    end select


end subroutine put_ion_default_a_1

subroutine take_ion_default_a_1(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, ion, empty)

    ! disable affected processes
    if(avail_sites(a_1_a_2, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(a_1_a_2, site)
    endif

    if(avail_sites(a_1_b_1, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(a_1_b_1, site)
    endif

    if(avail_sites(a_1_b_2, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(a_1_b_2, site)
    endif

    ! enable affected processes
    select case(get_species(site + (/0, 0, 0, default_a_2 - default_a_1/)))
    case(ion)
        call add_proc(a_2_a_1, site)
    end select

    select case(get_species(site + (/0, 0, 0, default_b_1 - default_a_1/)))
    case(ion)
        call add_proc(b_1_a_1, site)
    end select

    select case(get_species(site + (/0, 0, 0, default_b_2 - default_a_1/)))
    case(ion)
        call add_proc(b_2_a_1, site)
    end select


end subroutine take_ion_default_a_1

subroutine put_ion_default_a_2(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, empty, ion)

    ! disable affected processes
    if(avail_sites(a_1_a_2, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_a_1 - default_a_2)), 2).ne.0)then
        call del_proc(a_1_a_2, site + (/0, 0, 0, default_a_1 - default_a_2/))
    endif

    if(avail_sites(b_1_a_2, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(b_1_a_2, site)
    endif

    if(avail_sites(b_2_a_2, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(b_2_a_2, site)
    endif

    ! enable affected processes
    select case(get_species(site + (/0, 0, 0, default_a_1 - default_a_2/)))
    case(empty)
        call add_proc(a_2_a_1, site + (/0, 0, 0, default_a_1 - default_a_2/))
    end select

    select case(get_species(site + (/0, 0, 0, default_b_1 - default_a_2/)))
    case(empty)
        call add_proc(a_2_b_1, site)
    end select

    select case(get_species(site + (/0, 0, 0, default_b_2 - default_a_2/)))
    case(empty)
        call add_proc(a_2_b_2, site)
    end select


end subroutine put_ion_default_a_2

subroutine take_ion_default_a_2(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, ion, empty)

    ! disable affected processes
    if(avail_sites(a_2_a_1, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_a_1 - default_a_2)), 2).ne.0)then
        call del_proc(a_2_a_1, site + (/0, 0, 0, default_a_1 - default_a_2/))
    endif

    if(avail_sites(a_2_b_1, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(a_2_b_1, site)
    endif

    if(avail_sites(a_2_b_2, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(a_2_b_2, site)
    endif

    ! enable affected processes
    select case(get_species(site + (/0, 0, 0, default_a_1 - default_a_2/)))
    case(ion)
        call add_proc(a_1_a_2, site + (/0, 0, 0, default_a_1 - default_a_2/))
    end select

    select case(get_species(site + (/0, 0, 0, default_b_1 - default_a_2/)))
    case(ion)
        call add_proc(b_1_a_2, site)
    end select

    select case(get_species(site + (/0, 0, 0, default_b_2 - default_a_2/)))
    case(ion)
        call add_proc(b_2_a_2, site)
    end select


end subroutine take_ion_default_a_2

subroutine put_ion_default_b_1(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, empty, ion)

    ! disable affected processes
    if(avail_sites(a_1_b_1, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_a_1 - default_b_1)), 2).ne.0)then
        call del_proc(a_1_b_1, site + (/0, 0, 0, default_a_1 - default_b_1/))
    endif

    if(avail_sites(a_2_b_1, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_a_2 - default_b_1)), 2).ne.0)then
        call del_proc(a_2_b_1, site + (/0, 0, 0, default_a_2 - default_b_1/))
    endif

    if(avail_sites(b_2_b_1, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(b_2_b_1, site)
    endif

    ! enable affected processes
    select case(get_species(site + (/0, 0, 0, default_a_1 - default_b_1/)))
    case(empty)
        call add_proc(b_1_a_1, site + (/0, 0, 0, default_a_1 - default_b_1/))
    end select

    select case(get_species(site + (/0, 0, 0, default_a_2 - default_b_1/)))
    case(empty)
        call add_proc(b_1_a_2, site + (/0, 0, 0, default_a_2 - default_b_1/))
    end select

    select case(get_species(site + (/0, 0, 0, default_b_2 - default_b_1/)))
    case(empty)
        call add_proc(b_1_b_2, site)
    end select


end subroutine put_ion_default_b_1

subroutine take_ion_default_b_1(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, ion, empty)

    ! disable affected processes
    if(avail_sites(b_1_a_1, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_a_1 - default_b_1)), 2).ne.0)then
        call del_proc(b_1_a_1, site + (/0, 0, 0, default_a_1 - default_b_1/))
    endif

    if(avail_sites(b_1_a_2, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_a_2 - default_b_1)), 2).ne.0)then
        call del_proc(b_1_a_2, site + (/0, 0, 0, default_a_2 - default_b_1/))
    endif

    if(avail_sites(b_1_b_2, lattice2nr(site(1), site(2), site(3), site(4)), 2).ne.0)then
        call del_proc(b_1_b_2, site)
    endif

    ! enable affected processes
    select case(get_species(site + (/0, 0, 0, default_a_1 - default_b_1/)))
    case(ion)
        call add_proc(a_1_b_1, site + (/0, 0, 0, default_a_1 - default_b_1/))
    end select

    select case(get_species(site + (/0, 0, 0, default_a_2 - default_b_1/)))
    case(ion)
        call add_proc(a_2_b_1, site + (/0, 0, 0, default_a_2 - default_b_1/))
    end select

    select case(get_species(site + (/0, 0, 0, default_b_2 - default_b_1/)))
    case(ion)
        call add_proc(b_2_b_1, site)
    end select


end subroutine take_ion_default_b_1

subroutine put_ion_default_b_2(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, empty, ion)

    ! disable affected processes
    if(avail_sites(a_1_b_2, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_a_1 - default_b_2)), 2).ne.0)then
        call del_proc(a_1_b_2, site + (/0, 0, 0, default_a_1 - default_b_2/))
    endif

    if(avail_sites(a_2_b_2, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_a_2 - default_b_2)), 2).ne.0)then
        call del_proc(a_2_b_2, site + (/0, 0, 0, default_a_2 - default_b_2/))
    endif

    if(avail_sites(b_1_b_2, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_b_1 - default_b_2)), 2).ne.0)then
        call del_proc(b_1_b_2, site + (/0, 0, 0, default_b_1 - default_b_2/))
    endif

    ! enable affected processes
    select case(get_species(site + (/0, 0, 0, default_a_1 - default_b_2/)))
    case(empty)
        call add_proc(b_2_a_1, site + (/0, 0, 0, default_a_1 - default_b_2/))
    end select

    select case(get_species(site + (/0, 0, 0, default_a_2 - default_b_2/)))
    case(empty)
        call add_proc(b_2_a_2, site + (/0, 0, 0, default_a_2 - default_b_2/))
    end select

    select case(get_species(site + (/0, 0, 0, default_b_1 - default_b_2/)))
    case(empty)
        call add_proc(b_2_b_1, site + (/0, 0, 0, default_b_1 - default_b_2/))
    end select


end subroutine put_ion_default_b_2

subroutine take_ion_default_b_2(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    ! update lattice
    call replace_species(site, ion, empty)

    ! disable affected processes
    if(avail_sites(b_2_a_1, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_a_1 - default_b_2)), 2).ne.0)then
        call del_proc(b_2_a_1, site + (/0, 0, 0, default_a_1 - default_b_2/))
    endif

    if(avail_sites(b_2_a_2, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_a_2 - default_b_2)), 2).ne.0)then
        call del_proc(b_2_a_2, site + (/0, 0, 0, default_a_2 - default_b_2/))
    endif

    if(avail_sites(b_2_b_1, lattice2nr(site(1) + (0), site(2) + (0), site(3) + (0), site(4) + (default_b_1 - default_b_2)), 2).ne.0)then
        call del_proc(b_2_b_1, site + (/0, 0, 0, default_b_1 - default_b_2/))
    endif

    ! enable affected processes
    select case(get_species(site + (/0, 0, 0, default_a_1 - default_b_2/)))
    case(ion)
        call add_proc(a_1_b_2, site + (/0, 0, 0, default_a_1 - default_b_2/))
    end select

    select case(get_species(site + (/0, 0, 0, default_a_2 - default_b_2/)))
    case(ion)
        call add_proc(a_2_b_2, site + (/0, 0, 0, default_a_2 - default_b_2/))
    end select

    select case(get_species(site + (/0, 0, 0, default_b_1 - default_b_2/)))
    case(ion)
        call add_proc(b_1_b_2, site + (/0, 0, 0, default_b_1 - default_b_2/))
    end select


end subroutine take_ion_default_b_2

subroutine touchup_default_a_1(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    if (can_do(a_1_a_2, site)) then
        call del_proc(a_1_a_2, site)
    endif
    if (can_do(a_1_b_1, site)) then
        call del_proc(a_1_b_1, site)
    endif
    if (can_do(a_1_b_2, site)) then
        call del_proc(a_1_b_2, site)
    endif
    if (can_do(a_2_a_1, site)) then
        call del_proc(a_2_a_1, site)
    endif
    if (can_do(a_2_b_1, site)) then
        call del_proc(a_2_b_1, site)
    endif
    if (can_do(a_2_b_2, site)) then
        call del_proc(a_2_b_2, site)
    endif
    if (can_do(b_1_a_1, site)) then
        call del_proc(b_1_a_1, site)
    endif
    if (can_do(b_1_a_2, site)) then
        call del_proc(b_1_a_2, site)
    endif
    if (can_do(b_1_b_2, site)) then
        call del_proc(b_1_b_2, site)
    endif
    if (can_do(b_2_a_1, site)) then
        call del_proc(b_2_a_1, site)
    endif
    if (can_do(b_2_a_2, site)) then
        call del_proc(b_2_a_2, site)
    endif
    if (can_do(b_2_b_1, site)) then
        call del_proc(b_2_b_1, site)
    endif
    select case(get_species(site))
    case(empty)
        select case(get_species(site + (/0, 0, 0, default_a_2 - default_a_1/)))
        case(ion)
            call add_proc(a_2_a_1, site)
        end select

        select case(get_species(site + (/0, 0, 0, default_b_1 - default_a_1/)))
        case(ion)
            call add_proc(b_1_a_1, site)
        end select

        select case(get_species(site + (/0, 0, 0, default_b_2 - default_a_1/)))
        case(ion)
            call add_proc(b_2_a_1, site)
        end select

    case(ion)
        select case(get_species(site + (/0, 0, 0, default_a_2 - default_a_1/)))
        case(empty)
            call add_proc(a_1_a_2, site)
        end select

        select case(get_species(site + (/0, 0, 0, default_b_1 - default_a_1/)))
        case(empty)
            call add_proc(a_1_b_1, site)
        end select

        select case(get_species(site + (/0, 0, 0, default_b_2 - default_a_1/)))
        case(empty)
            call add_proc(a_1_b_2, site)
        end select

    end select

end subroutine touchup_default_a_1

subroutine touchup_default_a_2(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    if (can_do(a_1_a_2, site)) then
        call del_proc(a_1_a_2, site)
    endif
    if (can_do(a_1_b_1, site)) then
        call del_proc(a_1_b_1, site)
    endif
    if (can_do(a_1_b_2, site)) then
        call del_proc(a_1_b_2, site)
    endif
    if (can_do(a_2_a_1, site)) then
        call del_proc(a_2_a_1, site)
    endif
    if (can_do(a_2_b_1, site)) then
        call del_proc(a_2_b_1, site)
    endif
    if (can_do(a_2_b_2, site)) then
        call del_proc(a_2_b_2, site)
    endif
    if (can_do(b_1_a_1, site)) then
        call del_proc(b_1_a_1, site)
    endif
    if (can_do(b_1_a_2, site)) then
        call del_proc(b_1_a_2, site)
    endif
    if (can_do(b_1_b_2, site)) then
        call del_proc(b_1_b_2, site)
    endif
    if (can_do(b_2_a_1, site)) then
        call del_proc(b_2_a_1, site)
    endif
    if (can_do(b_2_a_2, site)) then
        call del_proc(b_2_a_2, site)
    endif
    if (can_do(b_2_b_1, site)) then
        call del_proc(b_2_b_1, site)
    endif
    select case(get_species(site))
    case(empty)
        select case(get_species(site + (/0, 0, 0, default_b_1 - default_a_2/)))
        case(ion)
            call add_proc(b_1_a_2, site)
        end select

        select case(get_species(site + (/0, 0, 0, default_b_2 - default_a_2/)))
        case(ion)
            call add_proc(b_2_a_2, site)
        end select

    case(ion)
        select case(get_species(site + (/0, 0, 0, default_b_1 - default_a_2/)))
        case(empty)
            call add_proc(a_2_b_1, site)
        end select

        select case(get_species(site + (/0, 0, 0, default_b_2 - default_a_2/)))
        case(empty)
            call add_proc(a_2_b_2, site)
        end select

    end select

end subroutine touchup_default_a_2

subroutine touchup_default_b_1(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    if (can_do(a_1_a_2, site)) then
        call del_proc(a_1_a_2, site)
    endif
    if (can_do(a_1_b_1, site)) then
        call del_proc(a_1_b_1, site)
    endif
    if (can_do(a_1_b_2, site)) then
        call del_proc(a_1_b_2, site)
    endif
    if (can_do(a_2_a_1, site)) then
        call del_proc(a_2_a_1, site)
    endif
    if (can_do(a_2_b_1, site)) then
        call del_proc(a_2_b_1, site)
    endif
    if (can_do(a_2_b_2, site)) then
        call del_proc(a_2_b_2, site)
    endif
    if (can_do(b_1_a_1, site)) then
        call del_proc(b_1_a_1, site)
    endif
    if (can_do(b_1_a_2, site)) then
        call del_proc(b_1_a_2, site)
    endif
    if (can_do(b_1_b_2, site)) then
        call del_proc(b_1_b_2, site)
    endif
    if (can_do(b_2_a_1, site)) then
        call del_proc(b_2_a_1, site)
    endif
    if (can_do(b_2_a_2, site)) then
        call del_proc(b_2_a_2, site)
    endif
    if (can_do(b_2_b_1, site)) then
        call del_proc(b_2_b_1, site)
    endif
    select case(get_species(site))
    case(empty)
        select case(get_species(site + (/0, 0, 0, default_b_2 - default_b_1/)))
        case(ion)
            call add_proc(b_2_b_1, site)
        end select

    case(ion)
        select case(get_species(site + (/0, 0, 0, default_b_2 - default_b_1/)))
        case(empty)
            call add_proc(b_1_b_2, site)
        end select

    end select

end subroutine touchup_default_b_1

subroutine touchup_default_b_2(site)

    integer(kind=iint), dimension(4), intent(in) :: site

    if (can_do(a_1_a_2, site)) then
        call del_proc(a_1_a_2, site)
    endif
    if (can_do(a_1_b_1, site)) then
        call del_proc(a_1_b_1, site)
    endif
    if (can_do(a_1_b_2, site)) then
        call del_proc(a_1_b_2, site)
    endif
    if (can_do(a_2_a_1, site)) then
        call del_proc(a_2_a_1, site)
    endif
    if (can_do(a_2_b_1, site)) then
        call del_proc(a_2_b_1, site)
    endif
    if (can_do(a_2_b_2, site)) then
        call del_proc(a_2_b_2, site)
    endif
    if (can_do(b_1_a_1, site)) then
        call del_proc(b_1_a_1, site)
    endif
    if (can_do(b_1_a_2, site)) then
        call del_proc(b_1_a_2, site)
    endif
    if (can_do(b_1_b_2, site)) then
        call del_proc(b_1_b_2, site)
    endif
    if (can_do(b_2_a_1, site)) then
        call del_proc(b_2_a_1, site)
    endif
    if (can_do(b_2_a_2, site)) then
        call del_proc(b_2_a_2, site)
    endif
    if (can_do(b_2_b_1, site)) then
        call del_proc(b_2_b_1, site)
    endif
end subroutine touchup_default_b_2

end module proclist
