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
!! \brief Computation of %timestep for energy & number density spectrum evolution in momentum space via CRESP algorithm
!<

module timestep_cresp
! pulled by CRESP

   implicit none

   private
   public :: dt_cre, cresp_timestep, dt_cre_synch, dt_cre_adiab, dt_cre_K, cresp_timestep_cell

   real :: dt_cre, dt_cre_synch, dt_cre_adiab, dt_cre_K

contains

   subroutine cresp_timestep

      use allreduce,        only: piernik_MPI_Allreduce
      use all_boundaries,   only: all_fluid_boundaries
      use cg_cost_data,     only: I_OTHER
      use cg_leaves,        only: leaves
      use cg_list,          only: cg_list_element
      use constants,        only: xdim, ydim, zdim, half, zero, pMIN, I_ONE
      use cresp_crspectrum, only: cresp_find_prepare_spectrum
      use crhelpers,        only: div_v, divv_i
      use cresp_helpers,    only: enden_CMB
      use fluidindex,       only: flind
      use func,             only: emag
      use grid_cont,        only: grid_container
      use initcosmicrays,   only: cfl_cr, iarr_crspc2_e, iarr_crspc2_n, nspc, diff_max_lev
      use initcrspectrum,   only: K_cresp_paral, K_cresp_perp, spec_mod_trms, synch_active, adiab_active, icomp_active, use_cresp_evol, cresp, f_synchIC, u_b_max, cresp_substep, n_substeps_max, redshift

      implicit none

      integer(kind=4)                :: i, j, k, i_up_max_tmp, i_up_max, i_spc ! NOTE i_up_max might be vectorised
      type(grid_container),  pointer :: cg
      type(cg_list_element), pointer :: cgl
      type(spec_mod_trms)            :: sptab
      real                           :: K_cre_max_sum, abs_max_ud, dt_aux
      logical                        :: empty_cell

      dt_cre       = huge(1.)
      dt_cre_K     = huge(1.)
      dt_cre_synch = huge(1.)
      dt_cre_adiab = huge(1.)

      if (.not. use_cresp_evol) return

      abs_max_ud   = zero
      i_up_max     = 1
      i_up_max_tmp = 1
      if (any(adiab_active(:))) call all_fluid_boundaries()

      cgl => leaves%first
      do while (associated(cgl))
         cg => cgl%cg
         call cg%costs%start

         if (any(adiab_active(:))) then
            call div_v(flind%ion%pos, cg)
            abs_max_ud = max(abs_max_ud, maxval(abs(cg%q(divv_i)%span(cg%ijkse))))
         endif

         do i_spc = 1, nspc
            sptab%ucmb = zero
            if (icomp_active(i_spc)) sptab%ucmb = enden_CMB(redshift) * f_synchIC(i_spc) ! NOTICE redshift is hard-coded to zero (current epoch)
            do k = cg%ks, cg%ke
               do j = cg%js, cg%je
                  do i = cg%is, cg%ie
                     sptab%ud = zero ; sptab%ub = zero ; sptab%umag = zero ; empty_cell = .false.
                     if (synch_active(i_spc)) sptab%umag = emag(cg%b(xdim,i,j,k), cg%b(ydim,i,j,k), cg%b(zdim,i,j,k)) * f_synchIC(i_spc)
                     cresp%n = cg%u(iarr_crspc2_n(i_spc,:), i, j, k)
                     cresp%e = cg%u(iarr_crspc2_e(i_spc,:), i, j, k)
                     call cresp_find_prepare_spectrum(cresp%n, cresp%e, i_spc, empty_cell, i_up_max_tmp) ! needed for synchrotron timestep
                     i_up_max = max(i_up_max, i_up_max_tmp)

                     sptab%ub = sptab%umag + sptab%ucmb  ! prepare term for synchrotron + IC losses

                     if (.not. empty_cell .and. synch_active(i_spc)) call cresp_timestep_synchrotron_IC(i_spc, min(sptab%ub, u_b_max), i_up_max_tmp) !dt_cre_synch = min(cresp_dt_synch_species(min(sptab%ub, u_b_max), i_up_max_tmp, i_spc), dt_cre_synch)
                  enddo
               enddo
            enddo
            !if (adiab_active(i_spc)) dt_cre_adiab = min(cresp_dt_adiab_species(i_spc, abs_max_ud, i_spc), dt_cre_adiab)
            if (adiab_active(i_spc)) call cresp_timestep_adiabatic(i_spc, abs_max_ud)
         enddo
         call cg%costs%stop(I_OTHER)
         cgl=>cgl%nxt
      enddo

      K_cre_max_sum = maxval(K_cresp_paral(:, i_up_max) + K_cresp_perp(:, i_up_max)) ! assumes the same K for energy and number density
      if (K_cre_max_sum > zero) then                               ! K_cre dependent on momentum - maximal for highest bin number
         dt_aux = cfl_cr * half / K_cre_max_sum                    ! We use cfl_cr here (CFL number for diffusive CR transport), cfl_cre used only for spectrum evolution
         cgl => leaves%first
         do while (associated(cgl))
            if (cgl%cg%l%id <= diff_max_lev) dt_cre_K = min(dt_cre_K, dt_aux * cgl%cg%dxmn2)
            cgl => cgl%nxt
         enddo
      endif

      call piernik_MPI_Allreduce(dt_cre_adiab, pMIN)
      call piernik_MPI_Allreduce(dt_cre_synch, pMIN)
      call piernik_MPI_Allreduce(dt_cre_K,     pMIN)

      dt_cre = min(dt_cre_adiab, dt_cre_synch)

      if (cresp_substep) then
      ! with cresp_substep enabled, dt_cre_adiab and dt_cre_synch are used only within CRESP module for substepping
      ! half * dt_spectrum * n_substeps_max tries to prevent number of substeps from exceeding n_substeps_max limit
         dt_cre = min(dt_cre * max(n_substeps_max-I_ONE, I_ONE), dt_cre_K)  ! number of substeps with dt_spectrum limited by n_substeps_max
      else
         dt_cre = min(dt_cre, dt_cre_K)                   ! dt comes in to cresp_crspectrum with factor * 2
      endif

   end subroutine cresp_timestep

!----------------------------------------------------------------------------------------------------

   subroutine cresp_timestep_adiabatic(i_spc, u_d_abs)

      use initcrspectrum, only: def_dtadiab, eps

      implicit none

      real, intent(in) :: u_d_abs    ! assumes that u_d > 0 always
      integer(kind=4), intent(in) :: i_spc

      if (u_d_abs > eps) dt_cre_adiab = def_dtadiab(i_spc) / u_d_abs

   end subroutine cresp_timestep_adiabatic

!----------------------------------------------------------------------------------------------------

   subroutine cresp_timestep_synchrotron_IC(i_spc, u_b, i_up_cell)

      use constants,      only: zero
      use initcrspectrum, only: def_dtsynchIC

      implicit none

      real,            intent(in) :: u_b
      integer(kind=4), intent(in) :: i_up_cell, i_spc
      real                        :: dt_cre_ub

      ! Synchrotron cooling timestep (is dependant only on p_up, highest value of p):
      if (u_b > zero) then
         dt_cre_ub = def_dtsynchIC(i_spc) / (assume_p_up(i_up_cell) * u_b)
         dt_cre_synch = min(dt_cre_ub, dt_cre_synch)    ! remember to max dt_cre_synch at the beginning of the search
      endif

   end subroutine cresp_timestep_synchrotron_IC

!----------------------------------------------------------------------------------------------------
!! \brief This subroutine returns timestep for cell at (i,j,k) position, with already prepared u_b and u_d values.

   subroutine cresp_timestep_cell(cresp_n, cresp_e, p_loss_terms, dt_cell, i_spc, empty_cell)

      use cresp_crspectrum, only: cresp_find_prepare_spectrum
      use initcosmicrays,   only: ncrb
      use initcrspectrum,   only: adiab_active, synch_active, spec_mod_trms

      implicit none

      real, dimension(1:ncrb), intent(inout) :: cresp_n, cresp_e
      type(spec_mod_trms), intent(in)  :: p_loss_terms
      integer(kind=4),     intent(in)  :: i_spc
      real,                intent(out) :: dt_cell
      logical,             intent(out) :: empty_cell
      integer(kind=4)                  :: i_up_cell

      dt_cell = huge(1.)
      dt_cre_adiab = huge(1.)
      dt_cre_synch = huge(1.)

      empty_cell = .false.

      call cresp_find_prepare_spectrum(cresp_n, cresp_e, i_spc, empty_cell, i_up_cell) ! needed for synchrotron timestep

      if (.not. empty_cell) then
         if (synch_active(i_spc)) call cresp_timestep_synchrotron_IC(i_spc, p_loss_terms%ub, i_up_cell)
         if (adiab_active(i_spc)) call cresp_timestep_adiabatic(i_spc, p_loss_terms%ud)
      else
         return
      endif

      dt_cell = min(dt_cre_adiab, dt_cre_synch)

   end subroutine cresp_timestep_cell

!----------------------------------------------------------------------------------------------------

   real function assume_p_up(cell_i_up)

      use initcosmicrays, only: ncrb
      use initcrspectrum, only: p_fix, p_mid_fix

      implicit none

      integer(kind=4), intent(in) :: cell_i_up

      if (cell_i_up == ncrb) then
         assume_p_up = p_mid_fix(ncrb) ! for i = 0 & ncrb p_fix(i) = 0.0
      else
         assume_p_up = p_fix(cell_i_up)
      endif

   end function assume_p_up

end module timestep_cresp
