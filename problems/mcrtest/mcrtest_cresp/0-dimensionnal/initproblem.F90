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

module initproblem

   implicit none

   private
   public :: read_problem_par, problem_initial_conditions, problem_pointers

   real :: d0, p0, bx0, by0, bz0, x0, y0, z0, r0, beta_cr, amp_cr1, amp_cr2, vxd0, vyd0, vzd0, expansion_cnst

   namelist /PROBLEM_CONTROL/ d0, p0, bx0, by0, bz0, x0, y0, z0, r0, vxd0, vyd0, vzd0, beta_cr, amp_cr1, amp_cr2, expansion_cnst

contains

!-----------------------------------------------------------------------------

   subroutine problem_pointers

      use dataio_user, only: user_tsl

      implicit none

      user_tsl => mcrtest_tsl

   end subroutine problem_pointers

!-----------------------------------------------------------------------------

   subroutine read_problem_par

      use bcast,      only: piernik_MPI_Bcast
      use dataio_pub, only: die, nh
      use domain,     only: dom
      use func,       only: operator(.equals.)
      use mpisetup,   only: rbuff, master, slave

      implicit none

      d0             = 1.0e5       !< density
      p0             = 1.0         !< pressure
      bx0            =   0.        !< Magnetic field component x
      by0            =   0.        !< Magnetic field component y
      bz0            =   0.        !< Magnetic field component z
      x0             = 0.0         !< x-position of the blob
      y0             = 0.0         !< y-position of the blob
      z0             = 0.0         !< z-position of the blob
      r0             = merge(0., 5.* minval(dom%L_(:)/dom%n_d(:), mask=dom%has_dir(:)), dom%eff_dim == 0)  !< radius of the blob
      vxd0           = 0.0         !< initial velocity_x, refers to whole domain
      vyd0           = 0.0         !< initial velocity_y, refers to whole domain
      vzd0           = 0.0         !< initial velocity_z, refers to whole domain
      expansion_cnst = 0.0

      beta_cr        = 0.0         !< ambient level
      amp_cr1        = 1.0         !< amplitude of the blob
      amp_cr2        = 0.1*amp_cr1 !< amplitude for the second species

      if (master) then

         if (.not.nh%initialized) call nh%init()
         open(newunit=nh%lun, file=nh%tmp1, status="unknown")
         write(nh%lun,nml=PROBLEM_CONTROL)
         close(nh%lun)
         open(newunit=nh%lun, file=nh%par_file)
         nh%errstr=""
         read(unit=nh%lun, nml=PROBLEM_CONTROL, iostat=nh%ierrh, iomsg=nh%errstr)
         close(nh%lun)
         call nh%namelist_errh(nh%ierrh, "PROBLEM_CONTROL")
         read(nh%cmdl_nml,nml=PROBLEM_CONTROL, iostat=nh%ierrh)
         call nh%namelist_errh(nh%ierrh, "PROBLEM_CONTROL", .true.)
         open(newunit=nh%lun, file=nh%tmp2, status="unknown")
         write(nh%lun,nml=PROBLEM_CONTROL)
         close(nh%lun)
         call nh%compare_namelist()

         rbuff(1)  = d0
         rbuff(2)  = p0
         rbuff(3)  = bx0
         rbuff(4)  = by0
         rbuff(5)  = bz0
         rbuff(6)  = x0
         rbuff(7)  = y0
         rbuff(8)  = z0
         rbuff(9)  = r0
         rbuff(10) = beta_cr
         rbuff(11) = amp_cr1
         rbuff(12) = amp_cr2
         rbuff(13) = vxd0
         rbuff(14) = vyd0
         rbuff(15) = vzd0
         rbuff(16) = expansion_cnst

      endif

      call piernik_MPI_Bcast(rbuff)

      if (slave) then

         d0        = rbuff(1)
         p0        = rbuff(2)
         bx0       = rbuff(3)
         by0       = rbuff(4)
         bz0       = rbuff(5)
         x0        = rbuff(6)
         y0        = rbuff(7)
         z0        = rbuff(8)
         r0        = rbuff(9)
         beta_cr   = rbuff(10)
         amp_cr1   = rbuff(11)
         amp_cr2   = rbuff(12)
         vxd0      = rbuff(13)
         vyd0      = rbuff(14)
         vzd0      = rbuff(15)
         expansion_cnst = rbuff(16)

      endif

      if (r0 .equals. 0.) call die("[initproblem:read_problem_par] r0 == 0")

   end subroutine read_problem_par

!-----------------------------------------------------------------------------

   subroutine problem_initial_conditions

      use allreduce,      only: piernik_MPI_Allreduce
      use cg_cost_data,   only: I_IC
      use cg_leaves,      only: leaves
      use cg_list,        only: cg_list_element
      use constants,      only: ndims, xdim, ydim, zdim, LO, HI, pMAX, BND_PER
      use dataio_pub,     only: msg, warn, printinfo
      use domain,         only: dom
      use fluidindex,     only: flind
      use fluidtypes,     only: component_fluid
      use func,           only: ekin, emag, operator(.equals.), operator(.notequals.)
      use grid_cont,      only: grid_container
      use mpisetup,       only: master
#ifdef COSM_RAYS
      use cr_data,        only: eCRSP, cr_spectral, icr_H1, icr_C12, cr_index, cr_table, eCRSP, rel_abound
      use initcosmicrays, only: iarr_crn, iarr_crs, gamma_cr_1, K_cr_paral, K_cr_perp
#ifdef CRESP
      use cresp_crspectrum, only: cresp_get_scaled_init_spectrum
      use initcosmicrays,   only: iarr_crspc2_e, iarr_crspc2_n, nspc
      use initcrspectrum,   only: expan_order, smallcree, cresp, cre_eff, use_cresp
#endif /* CRESP */
#endif /* COSM_RAYS */

      implicit none

      class(component_fluid), pointer :: fl
      integer                         :: i, j, k, icr, ipm, jpm, kpm
      integer, dimension(ndims,LO:HI) :: mantle
      real                            :: cs_iso, decr, r2, maxv
      type(cg_list_element),  pointer :: cgl
      type(grid_container),   pointer :: cg
#ifdef CRESP
      real                            :: e_tot

#endif /* CRESP */

      fl => flind%ion

! Uniform equilibrium state

      cs_iso = sqrt(p0/d0)

      if (.not.dom%has_dir(xdim)) bx0 = 0. ! ignore B field in nonexistent direction
      if (.not.dom%has_dir(ydim)) by0 = 0.
      if (.not.dom%has_dir(zdim)) bz0 = 0.

#ifdef COSM_RAYS
      if ((bx0**2 + by0**2 + bz0**2 .equals. 0.) .and. (any(K_cr_paral(:) .notequals. 0.) .or. any(K_cr_perp(:) .notequals. 0.))) then
         call warn("[initproblem:problem_initial_conditions] No magnetic field is set, K_cr_* also have to be 0.")
         K_cr_paral(:) = 0.
         K_cr_perp(:)  = 0.
      endif
#endif /* COSM_RAYS */

      mantle = 0
      do i = xdim, zdim
         if (any(dom%bnd(i,:) == BND_PER)) mantle(i,:) = [-1,1] !> for periodic boundary conditions
      enddo

      cgl => leaves%first
      do while (associated(cgl))
         cg => cgl%cg
         call cg%costs%start

         call cg%set_constant_b_field([bx0, by0, bz0])  ! this acts only inside cg%ijkse box
         cg%u(fl%idn,RNG) = d0
         cg%u(fl%imx:fl%imz,RNG) = 0.0
#ifdef IONIZED
! Velocity field
         if (expansion_cnst .notequals. 0.0 ) then ! adiabatic expansion / compression
            write(msg,*) '[initproblem:problem_initial_conditions] setting up expansion/compression, expansion_cnst = ',expansion_cnst
            call printinfo(msg)

            do k = cg%ks, cg%ke
               do j = cg%js, cg%je
                  do i = cg%is, cg%ie
                     cg%u(flind%ion%imx,i,j,k) = cg%u(flind%ion%idn,i,j,k) * (cg%x(i)-x0) * expansion_cnst  !< vxd0 * rho
                     cg%u(flind%ion%imy,i,j,k) = cg%u(flind%ion%idn,i,j,k) * (cg%y(j)-y0) * expansion_cnst  !< vyd0 * rho
                     cg%u(flind%ion%imz,i,j,k) = cg%u(flind%ion%idn,i,j,k) * (cg%z(k)-z0) * expansion_cnst  !< vzd0 * rho
                  enddo
               enddo
            enddo
         else
            cg%u(flind%ion%imx, RNG) = vxd0 * cg%u(flind%ion%idn, RNG)
            cg%u(flind%ion%imy, RNG) = vyd0 * cg%u(flind%ion%idn, RNG)
            cg%u(flind%ion%imz, RNG) = vzd0 * cg%u(flind%ion%idn, RNG)
         endif
#endif /* IONIZED */

#ifndef ISO
         cg%u(fl%ien,RNG) = p0/fl%gam_1 + ekin(cg%u(fl%imx,RNG), cg%u(fl%imy,RNG), cg%u(fl%imz,RNG), cg%u(fl%idn,RNG)) + &
              &             emag(cg%b(xdim,RNG), cg%b(ydim,RNG), cg%b(zdim,RNG))
#endif /* !ISO */

#ifdef COSM_RAYS
         cg%u(iarr_crs, RNG) = 0.0
         if (eCRSP(icr_H1 ) .and. .not. cr_spectral(cr_table(icr_H1)))  cg%u(iarr_crn(cr_index(icr_H1 )), RNG) = beta_cr * fl%cs2 * cg%u(fl%idn, RNG) / gamma_cr_1
         if (eCRSP(icr_C12) .and. .not. cr_spectral(cr_table(icr_C12))) cg%u(iarr_crn(cr_index(icr_C12)), RNG) = beta_cr * fl%cs2 * cg%u(fl%idn, RNG) / gamma_cr_1

! Explosions
         do k = cg%ks, cg%ke
            do j = cg%js, cg%je
               do i = cg%is, cg%ie

                  decr = 0.0
                  do ipm = mantle(xdim,LO), mantle(xdim,HI)
                     do jpm = mantle(xdim,LO), mantle(xdim,HI)
                        do kpm = mantle(xdim,LO), mantle(xdim,HI)
                           r2 = (cg%x(i)-x0+real(ipm)*dom%L_(xdim))**2+(cg%y(j)-y0+real(jpm)*dom%L_(ydim))**2+(cg%z(k)-z0+real(kpm)*dom%L_(zdim))**2
                                if (r2/r0**2 < 0.9999*log(huge(1.))) &  ! preventing numerical underflow
                                decr = decr + exp(-r2/r0**2)
                        enddo
                     enddo
                  enddo
                  if (eCRSP(icr_H1 ) .and. .not. cr_spectral(cr_table(icr_H1 )))  cg%u(iarr_crn(cr_index(icr_H1 )), i, j, k) = cg%u(iarr_crn(cr_index(icr_H1 )), i, j, k) + amp_cr1*decr
                  if (eCRSP(icr_C12) .and. .not. cr_spectral(cr_table(icr_C12)))  cg%u(iarr_crn(cr_index(icr_C12)), i, j, k) = cg%u(iarr_crn(cr_index(icr_C12)), i, j, k) + amp_cr2*decr
#ifdef CRESP
! Explosions @CRESP independent of cr nucleons
                  do icr = 1, nspc
                     e_tot = amp_cr1 * cre_eff(nspc) * decr
                     if (e_tot > smallcree .and. use_cresp) then
                        call cresp_get_scaled_init_spectrum(cresp%n, cresp%e, e_tot, icr)

                        cg%u(iarr_crspc2_n(icr,:),i,j,k) = cg%u(iarr_crspc2_n(icr,:),i,j,k) + rel_abound(icr)*cresp%n
                        cg%u(iarr_crspc2_e(icr,:),i,j,k) = cg%u(iarr_crspc2_e(icr,:),i,j,k) + rel_abound(icr)*cresp%e

                     endif
                  enddo
#endif /* CRESP */
               enddo
            enddo
         enddo

#endif /* COSM_RAYS */
         call cg%costs%stop(I_IC)
         cgl => cgl%nxt
      enddo
#ifdef COSM_RAYS
      do icr = 1, flind%crs%all

         maxv = - huge(1.)
         cgl => leaves%first
         do while (associated(cgl))
            call cgl%cg%costs%start
            associate (cg => cgl%cg)
               maxv = max(maxv, maxval(cg%u(iarr_crs(icr), RNG)))
            end associate
            call cgl%cg%costs%stop(I_IC)
            cgl => cgl%nxt
         enddo

         call piernik_MPI_Allreduce(maxv, pMAX)
         if (master) then
#ifdef CRESP
            if (iarr_crs(icr) < flind%crspc%nbeg) then
               write(msg,*) '[initproblem:problem_initial_conditions] icr(nuc)  =',icr,' maxecr(nuc) =',maxv
            else if (iarr_crs(icr) < flind%crspc%ebeg .and. iarr_crs(icr) >= flind%crspc%nbeg) then
               write(msg,*) '[initproblem:problem_initial_conditions] icr(cre_n)=',icr,' maxncr(cre) =',maxv
            else
               write(msg,*) '[initproblem:problem_initial_conditions] icr(cre_e)=',icr,' maxecr(cre) =',maxv
            endif
#else /* !CRESP */
            write(msg,*) '[initproblem:problem_initial_conditions] icr=', icr, ' maxecr =', maxv
#endif /* !CRESP */
            call printinfo(msg)
         endif

      enddo
#ifdef CRESP
      write(msg,*) '[initproblem:problem_initial_conditions]: Taylor_exp._ord. (cresp)    = ', expan_order
      if (master) call printinfo(msg)
#endif /* CRESP */
#endif /* COSM_RAYS */

   end subroutine problem_initial_conditions

   subroutine mcrtest_tsl(user_vars, tsl_names)

      use allreduce,        only: piernik_MPI_Allreduce
      use cg_cost_data,     only: I_IC
      use cg_leaves,        only: leaves
      use cg_list,          only: cg_list_element
      use constants,        only: pSUM
      use diagnostics,      only: pop_vector
      use grid_cont,        only: grid_container
      use mpisetup,         only: master
#ifdef COSM_RAYS
      use cr_data,          only: cr_table, icr_C12, icr_B10
#ifdef CRESP
      use initcosmicrays,   only: iarr_crspc2_n, ncrb
      !use initcrspectrum,   only: bin_old
#endif /* CRESP */
#endif /* COSM_RAYS */

      implicit none

      character(len=*), dimension(:), intent(inout), allocatable, optional :: tsl_names
      integer                                                              :: i, j, k
      real, dimension(:), intent(inout), allocatable                       :: user_vars
      real(kind=8), dimension(ncrb)                                        :: cr_total
      real(kind=8)                                                         :: output1, output2, output3
      !type(bin_old), dimension(:), allocatable                             :: crspc_bins_all
      type(cg_list_element), pointer                                       :: cgl
      type(grid_container), pointer                                        :: cg

      !allocate(crspc_bins_all(2*nspc*ncrb))
      !call ppp_main%start(crug_label)

      output1 = 0
      output2 = 0
      output3 = 0

      if (present(tsl_names)) then
         call pop_vector(tsl_names, len(tsl_names(1)), ["cr_C12n_tot"])    !   add to header
         call pop_vector(tsl_names, len(tsl_names(1)), ["cr_Be9n_tot"])    !   add to
         call pop_vector(tsl_names, len(tsl_names(1)), ["Total"])

      else

         cgl => leaves%first
         do while (associated(cgl))

            cg => cgl%cg
            call cg%costs%start

            ! do mpi stuff here...

            cr_total = 0

            do k = cg%ks, cg%ke
               do j = cg%js, cg%je
                  do i = cg%is, cg%ie

                     cr_total(:) = cg%u(iarr_crspc2_n(cr_table(icr_B10),:), i, j, k)+cg%u(iarr_crspc2_n(cr_table(icr_C12),:), i, j, k)

                     output1 = sum(cg%u(iarr_crspc2_n(cr_table(icr_C12),:), i, j, k))
                     output2 = sum(cg%u(iarr_crspc2_n(cr_table(icr_B10),:), i, j, k))
                     output3 = sum(cr_total(:))

                  enddo
               enddo
            enddo

            call cg%costs%stop(I_IC)
            cgl=>cgl%nxt

         enddo

         call piernik_MPI_Allreduce(output1, pSUM)
         if (master) call pop_vector(user_vars,[output1])
         call piernik_MPI_Allreduce(output2, pSUM)
         if (master) call pop_vector(user_vars,[output2])
         call piernik_MPI_Allreduce(output2, pSUM)
         if (master) call pop_vector(user_vars,[output3])!   pop value

      endif

      !deallocate(crspc_bins_all(2*nspc*ncrb))

   end subroutine mcrtest_tsl

end module initproblem
