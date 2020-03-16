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
!    along with PIERNIK.  If not, see http://www.gnu.org/licenses/.
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
!! \brief Unified refinement criteria for geometrical primitives
!!
!! \details Currently only points and boxes are implemented
!!
!! \todo Add sphere, shell, cylinder, etc.
!<

module unified_ref_crit_geometrical

   use unified_ref_crit, only: urc

   implicit none

   private
   public :: urc_geom

!> \brief Things that should be common for all refinement criteria based on geometrical primitives.

   type, abstract, extends(urc) :: urc_geom
      integer :: level  !< desired level of refinement
   end type urc_geom

end module unified_ref_crit_geometrical