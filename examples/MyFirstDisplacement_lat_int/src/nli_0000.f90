module nli_0000
use kind_values
use lattice
use proclist_constants
implicit none
contains
pure function nli_exc_left_down(cell)
    integer(kind=iint), dimension(4), intent(in) :: cell
    integer(kind=iint) :: nli_exc_left_down

    select case(get_species(cell + (/-1, -1, 0, default_a/)))
      case default
        nli_exc_left_down = 0; return
      case(empty)
        select case(get_species(cell + (/0, 0, 0, default_a/)))
          case default
            nli_exc_left_down = 0; return
          case(Au)
            nli_exc_left_down = exc_left_down; return
        end select
    end select

end function nli_exc_left_down

end module
