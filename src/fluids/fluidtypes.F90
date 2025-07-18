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
!! \brief Definitions of compound types for fluids
!<
module fluidtypes
! pulled by ANY
   use types,     only: value

   implicit none

   private
   public :: component, component_fluid, phys_prop, var_numbers
#ifdef CRESP
   public :: component_spectral
#endif /* CRESP */

   type :: phys_prop
      type(value) :: dens_min
      type(value) :: dens_max
      type(value) :: velx_max
      type(value) :: vely_max
      type(value) :: velz_max
      type(value) :: shear_max
      type(value) :: pres_max
      type(value) :: pres_min
      type(value) :: temp_max
      type(value) :: temp_min
      type(value) :: cs_max
      type(value) :: dtvx_min
      type(value) :: dtvy_min
      type(value) :: dtvz_min
      type(value) :: dtcs_min
      real        :: mmass_cur
      real        :: mmass_cum
   end type phys_prop

   type :: component
      integer(kind=4) :: all = 0   !< number of all variables in fluid/component
      integer(kind=4) :: beg = 0   !< beginning number of variables in fluid/component
      integer(kind=4) :: end = 0   !< end number of variables in fluid/component
      integer(kind=4) :: pos = 0   !< index denoting position of the fluid in the row of fluids
   end type component

#ifdef CRESP
   type, extends(component) :: component_spectral
      integer(kind=4) :: nbeg = 0  !< beginning number of number density components for fluid/component (cre) !!!
      integer(kind=4) :: ebeg = 0  !< beginning number of energy density components for fluid/component (cre) !!!
      integer(kind=4) :: nend = 0  !< end number of number density components for fluid/component (cre)       !!!
      integer(kind=4) :: eend = 0  !< end number of energy density components for fluid/component (cre)       !!!
   end type component_spectral
#endif /* CRESP */

   type, abstract, extends(component) :: component_fluid
      integer(kind=4) :: idn = -1      !< index denoting position of the fluid density in array arrays::u
      integer(kind=4) :: imx = -1      !< index denoting position of the fluid x-momentum in array arrays::u
      integer(kind=4) :: imy = -1      !< index denoting position of the fluid y-momentum in array arrays::u
      integer(kind=4) :: imz = -1      !< index denoting position of the fluid z-momentum in array arrays::u
      integer(kind=4) :: ien = -1      !< index denoting position of the fluid energy in array arrays::u

      real    :: cs    = 0.0   !< fluid\'s isothermal sound speed
      real    :: cs2   = 0.0   !< fluid\'s isothermal sound speed squared
      real    :: gam   = -1.0  !< fluid\'s adiabatic index
      real    :: gam_1 = -1.0  !< fluid\'s adiabatic index minus one

      logical :: is_selfgrav   = .false. !< True if fluid is selfgravitating
      logical :: is_magnetized = .false. !< True if fluid is magnetized
      logical :: has_energy    = .false. !< True if fluid has additional energy array

      integer :: tag = -1 !< Human readable tag describing fluid

      integer(kind=4), allocatable, dimension(:)   :: iarr
      integer(kind=4), allocatable, dimension(:,:) :: iarr_swp

      type(phys_prop) :: snap

      real :: c !< COMMENT ME (this quantity was previously a member of phys_prop, but is used in completely different way than other phys_prop% members
      real :: c_old

   contains
      procedure :: set_fluid_index
      procedure :: set_cs  => update_sound_speed
      procedure :: set_gam => update_adiabatic_index
      procedure :: set_c   => update_freezing_speed
      procedure :: res_c   => reset_freezing_speed
      procedure :: info    => printinfo_component_fluid
      procedure(tag),          nopass, deferred :: get_tag
      procedure(cs_get),         pass, deferred :: get_cs
      procedure(cs_get),         pass, deferred :: get_mach
      procedure(flux_interface), pass, deferred :: compute_flux
      procedure(pres_interface), pass, deferred :: compute_pres
      procedure(pass_flind),     pass, deferred :: initialize_indices
   end type component_fluid

   type :: fluid_arr
      class(component_fluid), pointer :: fl
   end type fluid_arr

   type :: var_numbers
      integer(kind=4) :: all         = 0      !< total number of fluid variables = the size of array \a u(:,:,:,:) in the first index
      integer(kind=4) :: fluids      = 0      !< number of fluids (ionized gas, neutral gas, dust)
      integer(kind=4) :: energ       = 0      !< number of non-isothermal fluids (indicating the presence of energy density in the vector of conservative variables)
      integer(kind=4) :: components  = 0      !< number of components, such as CRs, tracers, magnetic helicity (in future), whose formal description does not involve [???]
      integer(kind=4) :: fluids_sg   = 0      !< number of selfgravitating fluids (ionized gas, neutral gas, dust)

      type(fluid_arr), dimension(:), pointer :: all_fluids

      class(component_fluid), pointer :: ion         !< numbers of variables for the ionized fluid
      class(component_fluid), pointer :: neu         !< numbers of variables for the neutral fluid
      class(component_fluid), pointer :: dst         !< numbers of variables for the dust fluid

      !> \todo those vars should be converted to pointers
      type(component) :: trc         !< numbers of tracer fluids
      type(component) :: crs         !< numbers of variables in all cosmic ray components
      type(component) :: crn         !< numbers of variables in cosmic ray nuclear components
#ifdef CRESP
      type(component_spectral) :: crspc                            !< variables in cosmic ray spectral components
      type(component_spectral),dimension(:),allocatable :: crspcs  !< variables in cosmic ray spectral components
#endif /* CRESP */
   contains
      procedure :: any_fluid_is_selfgrav
   end type var_numbers

   abstract interface
      subroutine pass_flind(this, flind)
         import
         implicit none
         class(component_fluid), intent(inout) :: this
         type(var_numbers), intent(inout) :: flind
      end subroutine pass_flind

      !> \todo try to remove dependency of this module on the grid_container
      real function cs_get(this, i, j, k, u, b, cs_iso2)
         import
         implicit none
         class(component_fluid),            intent(in) :: this
         integer,                           intent(in) :: i, j, k !< cell indices
         real, dimension(:,:,:,:), pointer, intent(in) :: u       !< pointer to array of fluid properties
         real, dimension(:,:,:,:), pointer, intent(in) :: b       !< pointer to array of magnetic fields (used for ionized fluid with MAGNETIC #defined)
         real, dimension(:,:,:),   pointer, intent(in) :: cs_iso2 !< pointer to array of isothermal sound speeds (used when ISO was #defined)
      end function cs_get

      function tag()
         use constants, only: idlen
         implicit none
         character(len=idlen)   :: tag
      end function tag

      subroutine flux_interface(this, flux, cfr, uu, n, vx, bb, cs_iso2)
         import
         implicit none
         class(component_fluid), intent(in)           :: this
         integer(kind=4),      intent(in)             :: n        !< number of cells in the current sweep
         real, dimension(:,:), intent(inout), pointer :: flux     !< flux of fluid
         real, dimension(:,:), intent(in),    pointer :: uu       !< part of u for fluid
         real, dimension(:,:), intent(inout), pointer :: cfr      !< freezing speed for fluid
         real, dimension(:,:), intent(in),    pointer :: bb       !< magnetic field x,y,z-components table
         real, dimension(:),   intent(in),    pointer :: vx       !< velocity of fluid for current sweep
         real, dimension(:),   intent(in),    pointer :: cs_iso2  !< isothermal sound speed squared
      end subroutine flux_interface

      subroutine pres_interface(this, n, uu, bb, cs_iso2, ps)
         import
         implicit none
         class(component_fluid), intent(in)             :: this
         integer(kind=4),        intent(in)             :: n        !< number of cells in the current sweep
         real, dimension(:,:),   intent(in),    pointer :: uu       !< part of u for fluid
         real, dimension(:,:),   intent(in),    pointer :: bb       !< magnetic field x,y,z-components table
         real, dimension(:),     intent(in),    pointer :: cs_iso2  !< isothermal sound speed squared
         real, dimension(:),     intent(inout), pointer :: ps       !< pressure of fluid for current sweep
      end subroutine pres_interface
   end interface

contains

   subroutine update_adiabatic_index(this,new_gamma)

      use dataio_pub, only: warn

      implicit none

      class(component_fluid) :: this
      real, intent(in)       :: new_gamma

      if (.not.this%has_energy) then
         call warn("Fluid does not have energy component")
         call warn("Updating gamma does not make much sense o.O")
      endif
      this%gam   = new_gamma
      this%gam_1 = new_gamma-1.0

   end subroutine update_adiabatic_index

   subroutine update_freezing_speed(this, new_c)

      implicit none

      class(component_fluid) :: this
      real, intent(in)       :: new_c

      this%c_old = this%c
      this%c     = new_c

   end subroutine update_freezing_speed

   subroutine reset_freezing_speed(this)

      implicit none

      class(component_fluid) :: this

      this%c     = this%c_old

   end subroutine reset_freezing_speed

   subroutine update_sound_speed(this,new_cs)

      implicit none

      class(component_fluid) :: this
      real, intent(in)       :: new_cs

      this%cs  = new_cs
      this%cs2 = new_cs**2

   end subroutine update_sound_speed

   subroutine printinfo_component_fluid(this)

      use dataio_pub,  only: msg, printinfo

      implicit none

      class(component_fluid), intent(in) :: this

      write(msg,*) "idn   = ", this%idn;     call printinfo(msg)
      write(msg,*) "imx   = ", this%imx;     call printinfo(msg)
      write(msg,*) "imy   = ", this%imy;     call printinfo(msg)
      write(msg,*) "imz   = ", this%imz;     call printinfo(msg)
      write(msg,*) "ien   = ", this%ien;     call printinfo(msg)

      write(msg,*) "cs    = ", this%cs;      call printinfo(msg)
      write(msg,*) "cs2   = ", this%cs2;     call printinfo(msg)
      write(msg,*) "gam   = ", this%gam;     call printinfo(msg)
      write(msg,*) "gam_1 = ", this%gam_1;   call printinfo(msg)

      if (this%is_selfgrav) then
         write(msg,*) "Fluid is selfgravitating"; call printinfo(msg)
      endif
      if (this%is_magnetized) then
         write(msg,*) "Fluid is magnetized";      call printinfo(msg)
      endif
      if (this%has_energy) then
         write(msg,*) "Fluid has energy";         call printinfo(msg)
      endif
      write(msg,*) "TAG   = ", this%tag;     call printinfo(msg)

   end subroutine printinfo_component_fluid

!>
!! \deprecated repeated magic integers
!<
   subroutine set_fluid_index(this, flind, is_magnetized, is_selfgrav, has_energy, cs_iso, gamma_, tag)

      use constants,   only: xdim, ydim, zdim, ndims, I_ONE, ION, NEU, DST, cbuff_len, V_VERBOSE
      use dataio_pub,  only: msg, printinfo
      use diagnostics, only: ma1d, ma2d, my_allocate
      use mpisetup,    only: master

      implicit none

      class(component_fluid), intent(inout) :: this
      type(var_numbers),      intent(inout) :: flind

      logical,                intent(in)    :: is_selfgrav, is_magnetized, has_energy
      real,                   intent(in)    :: cs_iso, gamma_
      integer(kind=4)                       :: tag
      character(len=cbuff_len)              :: aux

      this%beg    = flind%all + I_ONE

      this%idn = this%beg
      this%imx = this%idn + I_ONE
      this%imy = this%imx + I_ONE
      this%imz = this%imy + I_ONE

      this%all  = 4
      flind%all      = this%imz
      if (has_energy) then
         flind%all = flind%all + I_ONE

         this%ien  = this%imz + I_ONE
         this%all  = this%all + I_ONE
      endif

      ma1d = [this%all]
      call my_allocate(this%iarr,     ma1d)
      ma2d = [ndims, this%all]
      call my_allocate(this%iarr_swp, ma2d)

      this%iarr(1:4)           = [this%idn, this%imx, this%imy, this%imz]
      this%iarr_swp(xdim, 1:4) = [this%idn, this%imx, this%imy, this%imz]
      this%iarr_swp(ydim, 1:4) = [this%idn, this%imy, this%imx, this%imz]
      this%iarr_swp(zdim, 1:4) = [this%idn, this%imz, this%imy, this%imx]

      if (has_energy) then
         this%iarr(5)       = this%ien
         this%iarr_swp(:,5) = this%ien

         flind%energ = flind%energ + I_ONE
      endif

      this%end    = flind%all
      flind%components = flind%components + I_ONE
      flind%fluids     = flind%fluids + I_ONE
      this%pos    = flind%components
      if (is_selfgrav)  flind%fluids_sg = flind%fluids_sg + I_ONE

      this%gam   = gamma_
      this%gam_1 = gamma_ - 1.0
      this%cs    = cs_iso
      this%cs2   = cs_iso**2
      this%tag   = tag

      this%has_energy    = has_energy
      this%is_selfgrav   = is_selfgrav
      this%is_magnetized = is_magnetized

      msg = "Registered"
      select case (tag)
         case (ION)
            msg = trim(msg) // " ionized"
         case (NEU)
            msg = trim(msg) // " neutral"
         case (DST)
            msg = trim(msg) // " dust"
         case default
            msg = trim(msg) // " unknown"
      end select
      msg = trim(msg) // " fluid:"
      write(aux, '(A,F7.4)') " gamma = ", gamma_
      msg = trim(msg) // aux
      if (is_magnetized) msg = trim(msg) // ", magnetized"
      if (is_selfgrav) msg = trim(msg) // ", selfgravitating"
      if (has_energy) then
         msg = trim(msg) // ", with energy"
      else
         msg = trim(msg) // ", isothermal with c_sound = "
         write(aux, '(G10.2)') cs_iso
         msg = trim(msg) // aux
      endif

      if (master) call printinfo(msg, V_VERBOSE)

   end subroutine set_fluid_index

!>
!! \brief returns True value if any fluid is selfgravitating
!<
   function any_fluid_is_selfgrav(this) result(tf)

      implicit none

      class(var_numbers), intent(in) :: this

      logical :: tf
      integer :: ifl

      tf = .false.
      do ifl = lbound(this%all_fluids, 1), ubound(this%all_fluids, 1)
         tf = tf .or. this%all_fluids(ifl)%fl%is_selfgrav
      enddo

   end function any_fluid_is_selfgrav

end module fluidtypes
