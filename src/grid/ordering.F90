! $Id$
!
! PIERNIK Code Copyright (C) 2006 Michal Hanasz
!
!    This file is part of PIERNIK code.
!
!    PIERNIK is free software: you can redistribute it and/or modify
!    it under the terms of the GNU General Public License as published by
!    the Free Software Foundation, either version 3 of the License, or
!    (at your option) any later version.
!
!    PIERNIK is distributed in the hope that it will be useful,
!    but WITHOUT ANY WARRANTY; without even the implied warranty of
!    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!    GNU General Public License for more details.
!
!    You should have received a copy of the GNU General Public License
!    along with PIERNIK.  If not, see <http://www.gnu.org/licenses/>.
!
!    Initial implementation of PIERNIK code was based on TVD split MHD code by
!    Ue-Li Pen
!        see: Pen, Arras & Wong (2003) for algorithm and
!             http://www.cita.utoronto.ca/~pen/MHD
!             for original source code "mhd.f90"
!
!    For full list of developers see $PIERNIK_HOME/license/pdt.txt
!

#include "piernik.h"

!>
!! \brief Functions that convert coordinates into single integer (position on a Z/Morton space-filling curve)
!!
!! \todo implement also Hilbert ordering
!<

module ordering

   implicit none

   private
   public :: Morton_order

contains

!> \brief Wrapper for Morton_id

   function Morton_order(off) result(id)

      use constants,  only: ndims, xdim, ydim, zdim, INVALID
      use dataio_pub, only: die
      use domain,     only: dom

      implicit none

      integer(kind=8), dimension(ndims), intent(in) :: off

      integer(kind=8) :: id
      integer :: j1, j2

      id = INVALID
      select case (dom%eff_dim)
         case (1) ! No need to process coordinate
            do j1 = xdim, zdim
               if (dom%has_dir(j1)) id = off(j1)
            enddo
         case (2) ! select coordinates only in existing dimensions
            if (dom%has_dir(xdim)) then
               j1 = xdim
            else
               j1 = ydim
            endif
            if (dom%has_dir(zdim)) then
               j2 = zdim
            else
               j2 = ydim
            endif
            id = Morton_id([ off(j1), off(j2) ])
         case (3) ! just do the conversion
            id = Morton_id(off)
         case default
            call die("[ordering:Morton_order] invalid dimensionality")
      end select

      if (id == INVALID) call die("[ordering:Morton_order] invalid id")

   end function Morton_order

!> \brief Convert contigous vector of coordinates into its Morton identifier

   function Morton_id(off) result(id)

      use dataio_pub, only: die

      implicit none

      integer(kind=8), dimension(:), intent(in) :: off

      integer(kind=8) :: id
      integer(kind=8), allocatable, dimension(:) :: o
      integer :: i
      integer(kind=8) :: mask

      allocate(o(size(off)))
      o = off
      id = 0
      mask = 1
      do while (any(o /= 0))
         do i = lbound(o, dim=1), ubound(o, dim=1)
            if (btest(o(i), 0)) then
               id = ior(id, mask)
               if (mask <= 0) call die("[ordering:Morton_id] mask overflow")
            endif
            mask = ishft(mask, 1)
         enddo
         o(:) = ishft(o, -1)
      enddo
      deallocate(o)

      !id = ieor(id, ishft(id, -1)) Gray code

   end function Morton_id

end module ordering