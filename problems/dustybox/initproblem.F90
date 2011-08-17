! $Id: initproblem.F90 4543 2011-06-21 13:01:45Z gawrysz $
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
#include "macros.h"

module initproblem

! Initial condition for dust fronts
! Written by: M. Hanasz, January 2009
   implicit none

   private
   public :: read_problem_par, init_prob, problem_pointers

   real      :: rhog, rhod, vxg0, vyg0, vzg0, vxd0, vyd0, vzd0

   namelist /PROBLEM_CONTROL/  rhog, rhod, vxg0, vyg0, vzg0, vxd0, vyd0, vzd0

contains

!-----------------------------------------------------------------------------
   subroutine problem_pointers

      implicit none

   end subroutine problem_pointers
!-----------------------------------------------------------------------------
   subroutine read_problem_par

      use dataio_pub,    only: par_file, ierrh, namelist_errh, compare_namelist, cmdl_nml     ! QA_WARN required for diff_nml
      use mpi,           only: MPI_DOUBLE_PRECISION
      use mpisetup,      only: rbuff, comm, ierr, buffer_dim, master, slave

      implicit none

      rhog         = 1.0
      rhod         = 0.01
      vxd0         = sqrt(1./3.)
      vyd0         = sqrt(1./3.)
      vzd0         = sqrt(1./3.)
      vxg0         = -sqrt(1./3.)
      vyg0         = -sqrt(1./3.)
      vzg0         = -sqrt(1./3.)

      if (master) then

         diff_nml(PROBLEM_CONTROL)

         rbuff(1) = rhog
         rbuff(2) = rhod
         rbuff(3) = vxg0
         rbuff(4) = vyg0
         rbuff(5) = vzg0
         rbuff(6) = vxd0
         rbuff(7) = vyd0
         rbuff(8) = vzd0

      endif

      call MPI_Bcast(rbuff, buffer_dim, MPI_DOUBLE_PRECISION, 0, comm, ierr)

      if (slave) then

         rhog         = rbuff(1)
         rhod         = rbuff(2)
         vxg0         = rbuff(3)
         vyg0         = rbuff(4)
         vzg0         = rbuff(5)
         vxd0         = rbuff(6)
         vyd0         = rbuff(7)
         vzd0         = rbuff(8)

      endif

   end subroutine read_problem_par
!-----------------------------------------------------------------------------
   subroutine init_prob

      use grid,       only: cga
      use grid_cont,  only: cg_list_element, grid_container
      use fluidindex, only: flind

      implicit none

      type(cg_list_element), pointer :: cgl
      type(grid_container), pointer :: cg

      call cga%get_root(cgl)
      do while (associated(cgl))
         cg => cgl%cg

         cg%u%arr(flind%neu%idn,:,:,:) = rhog
         cg%u%arr(flind%neu%imx,:,:,:) = rhog*vxg0
         cg%u%arr(flind%neu%imy,:,:,:) = rhog*vyg0
         cg%u%arr(flind%neu%imz,:,:,:) = rhog*vzg0

         cg%u%arr(flind%dst%idn,:,:,:) =  rhod
         cg%u%arr(flind%dst%imx,:,:,:) = -rhod*vxd0
         cg%u%arr(flind%dst%imy,:,:,:) = -rhod*vyd0
         cg%u%arr(flind%dst%imz,:,:,:) = -rhod*vzd0

         cgl => cgl%nxt
      enddo

   end subroutine init_prob
!-----------------------------------------------------------------------------
!-----------------------------------------------------------------------------
end module initproblem