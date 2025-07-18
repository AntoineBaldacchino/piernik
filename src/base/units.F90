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
!! \brief Module containing physical %constants and %units
!! \details Module units contains physical %constants for several units systems.
!! To use one system a proper value of units_set should be set.
!! Available units systems defined by units_set value:
!! @n
!! @n @b PSM (Parsec - Solar_mass - Megayear) - good for global galactic simulations
!! @n length --> pc,     mass --> Msun,        time --> myr,        miu0 --> 4*pi,    temperature --> kelvin
!! @n
!! @n @b PLN (PLaNetary) - good for planetary nebulae
!! @n length --> AU,     mass --> Mjup,        time --> yr,         miu0 --> 4*pi,    temperature --> kelvin
!! @n
!! @n @b BIN (Binary system) - good for binary systems
!! @n length --> AU,     mass --> Msun,        time --> yr,         miu0 --> 4*pi,    temperature --> kelvin
!! @n
!! @n @b KSG (Kiloparsec - Solar_mass - Gigayear) - good for galactic and intergalactic simulations
!! @n length --> kpc,    mass --> 10^6*Msun,   time --> Gyr,        miu0 --> 4*pi,    temperature --> kelvin
!! @n
!! @n @b KSM (Kiloparsec - Solar_mass - Megayear)
!! @n length --> kpc,    mass --> Msun,        time --> myr,        miu0 --> 4*pi,    temperature --> kelvin
!! @n
!! @n @b PGM (Parsec - Gravity=1 - Megayear) - modification of PSM system, where %gravity constant is one
!! @n length --> pc,     newtong --> 1.0,      time --> myr,        miu0 --> 4*pi,    temperature --> kelvin
!! @n
!! @n @b SSY (10^Sixteenth cm - Solar_mass - Year) - good for circumstellar simulations (planetaries etc.)
!! @n length --> 10^16 cm,  mass --> Msun,     time --> year,       miu0 --> 4*pi,    temperature --> kelvin
!! @n
!! @n @b SI - (franc. Système International d'Unités) '
!! @n length --> metr,   mass --> kg,          time --> sek,        miu0 --> 4*pi,    temperature --> kelvin
!! @n
!! @n @b CGS - (Centimetre - Gram - Second)
!! @n length --> cm,     mass --> gram,        time --> sek,        miu0 --> 4*pi,    temperature --> kelvin
!! @n
!! @n @b WT4 - unit system for Wengen Test #4
!! @n length --> 6.25AU, mass --> 0.1 M_sun,   time --> 2.5**3.5  pi years (=> G &asymp; 1.)
!! @n
!! @n @b USER - units system defined by user
!! @n following variables from UNITS namelist should be specified: miu0, kelvin, cm, gram, sek
!! @n
!! @n @b SCALED - a suit of %units without physical units. This is automatically set while neither of the former systems is chosen.
!<
module units

   use constants, only: cbuff_len, U_LEN, U_MAG, U_ENER

   implicit none

   public                                                ! QA_WARN no secrets are kept here
   private :: au_cm, pc_au, pc_cm, msun_g, mjup_g, day_s, yr_day, yr_s, newton_cgs!, kB_cgs  ! QA_WARN don't use those vars outside units!

   character(len=cbuff_len) :: units_set                 !< type of units set
   character(len=cbuff_len) :: s_len_u                   !< name of length unit
   character(len=cbuff_len) :: s_time_u                  !< name of time unit
   character(len=cbuff_len) :: s_mass_u                  !< name of mass unit
   character(len=cbuff_len), dimension(U_LEN:U_ENER), target :: s_lmtvB   !< [length, mass, time, velocity, magnetic] units (used in GDF 1.1)
   real(kind=8), dimension(U_LEN:U_MAG)                      :: lmtvB     !< [length, mass, time, velocity, magnetic] units conversion factors (used in GDF 1.1)

   real(kind=8), parameter :: au_cm       =  1.49597870700d13   ! Astonomical unit [cm] (IAU 2009)
   real(kind=8), parameter :: pc_au       =  206264.806248712   ! Parsec [AU] 1 pc/1 AU = 1./atan(pi/180. * 1./3600.)
   real(kind=8), parameter :: pc_cm       =  pc_au*au_cm        ! Parsec [cm]
   real(kind=8), parameter :: Msun_g      =  1.9884e33          ! Solar mass [g]  Astronomical Alamach 2013
   real(kind=8), parameter :: Mjup_g      =  Msun_g/1.047348644e3 ! Jovian mass [g]  (IAU 2009)
   real(kind=8), parameter :: day_s       =  24.0*3600.0        ! Earth's day [s]
   real(kind=8), parameter :: yr_day      =  365.2563630510     ! sideral year [days]
   real(kind=8), parameter :: yr_s        =  yr_day*day_s       ! Year [s]
   real(kind=8), parameter :: newton_cgs  =  6.67428e-8         ! Gravitational constant [ cm^3 / g s^2 ]
   real(kind=8), parameter :: kB_cgs      =  1.3806504e-16      ! Boltzmann constant [ g cm^2 / K s^2 ]

   real, protected :: cm      !< centimetre, length unit
   real, protected :: gram    !< gram, mass unit
   real, protected :: sek     !< second, time unit
   real, protected :: miu0    !< permeability
   real, protected :: kelvin  !< kelvin, temperature unit

! length units:
   real, protected :: metr                                  !< metre, length unit
   real, protected :: km                                    !< kilometer, length unit
   real, protected :: au                                    !< astronomical unit (length unit)
   real, protected :: pc                                    !< parsec, length unit
   real, protected :: kpc                                   !< kiloparsec, length unit
   real, protected :: lyr                                   !< light year, length unit
! time units:
   real, protected :: minute                                !< minute, time unit
   real, protected :: hour                                  !< hour, time unit
   real, protected :: day                                   !< day, time unit
   real, protected :: year                                  !< year, time unit
   real, protected :: myr                                   !< megayear, time unit
! mass units:
   real, protected :: kg                                    !< kilogram, mass unit
   real, protected :: me                                    !< electron mass
   real, protected :: mp                                    !< proton mass
   real, protected :: mH                                    !< hydrogen atom mass
   real, protected :: amu                                   !< atomic mass unit
   real, protected :: Msun                                  !< Solar mass, mass unit
   real, protected :: gmu                                   !< galactic mass unit
! force units:
   real, protected :: newton                                !< 1N (SI force unit)
   real, protected :: dyna                                  !< 1 dyna (cgs force unit)
! energy units:
   real, protected :: joul                                  !< 1J (SI energy unit)
   real, protected :: erg                                   !< 1 erg (cgs energy unit)
   real, protected :: eV                                    !< 1 eV
! area (cross section) units:
   real, protected :: barn                                  !< barn (cross section unit)
   real, protected :: mbarn                                 !< milibarn (cross section unit)
! density units:
   real, protected :: ppcm3                                 !< spatial density unit
   real, protected :: ppcm2                                 !< column density unit
! physical constants:
   real, protected :: kboltz                                !< boltzmann constant
   real, protected :: gasRconst                             !< gas constant R =  8.314472e7*erg/kelvin/mol
   real, protected :: N_A                                   !< Avogadro constant
   real, protected :: clight                                !< speed of light in vacuum
   real, protected :: sigma_T                               !< Thomson cross section
   real, protected :: Gs                                    !< 1 Gs (cgs magnetic induction unit)
   real, protected :: mGs                                   !< 1 microgauss
   real, protected :: Tesla                                 !< 1 T (SI magnetic induction unit)
   real, protected :: newtong                               !< newtonian constant of gravitation
   real, protected :: fpiG                                  !< four Pi times Newtonian constant of gravitation (commonly used in self-gravity routines)
   real, protected :: planck                                !< Planck constant
   real, protected :: r_gc_sun                              !< Sun distance from the Galaxy Center
   real, protected :: vsun                                  !< velocity value of Sun in the Galaxy
   real, protected :: sunradius                             !< radius of Sun
   real, protected :: u_CMB                                 !< Cosmic Microwave Background energy density at current epoch
   real, protected :: Lsun                                  !< luminosity of Sun
   real, protected :: Mearth                                !< mass of Earth
   real, protected :: earthradius                           !< radius of Earth
   real, protected :: TempHalo                              !< Initial temperature of the halo
   real, protected :: Lambda_C                              !< Couling time of Coulomb loss for non-spectral protons
   real, protected :: Lambda_Cc                             !< Couling time of Coulomb loss for spectral CRs

contains
!>
!! \brief Routine initializing units module
!!
!! \details
!! @b UNITS
!! \n \n
!! <table border="+1">
!! <tr><td width="150pt"><b>parameter</b></td><td width="135pt"><b>default value</b></td><td width="200pt"><b>possible values</b></td><td width="315pt"> <b>description</b></td></tr>
!! <tr><td>units_set </td><td>'scaled'    </td><td>string of characters</td><td>type of units set       </td></tr>
!! <tr><td>miu0      </td><td>4*pi        </td><td>real                </td><td>\copydoc units::miu0    </td></tr>
!! <tr><td>kelvin    </td><td>1           </td><td>real                </td><td>\copydoc units::kelvin  </td></tr>
!! <tr><td>cm        </td><td>1           </td><td>real                </td><td>\copydoc units::cm      </td></tr>
!! <tr><td>gram      </td><td>1           </td><td>real                </td><td>\copydoc units::gram    </td></tr>
!! <tr><td>sek       </td><td>1           </td><td>real                </td><td>\copydoc units::sek     </td></tr>
!! <tr><td>s_len_u   </td><td>' undefined'</td><td>string of characters</td><td>\copydoc units::s_len_u </td></tr>
!! <tr><td>s_time_u  </td><td>' undefined'</td><td>string of characters</td><td>\copydoc units::s_time_u</td></tr>
!! <tr><td>s_mass_u  </td><td>' undefined'</td><td>string of characters</td><td>\copydoc units::s_mass_u</td></tr>
!! </table>
!! \n \n
!! \deprecated BEWARE: miu0 and kelvin may be overwritten by values from problem.par even though we choose units_set value one of the following
!! nevertheless, they are not used so far (r3612)
!<
   subroutine init_units

      use constants,  only: pi, fpi, dirtyL, PIERNIK_INIT_MPI, U_TEMP, V_VERBOSE, V_INFO
      use dataio_pub, only: warn, printinfo, msg, die, code_progress
      use func,       only: operator(.equals.)
      use mpisetup,   only: master

      implicit none

      logical, save            :: scale_me = .false.
      integer(kind=4) :: v

      v = V_VERBOSE

      if (code_progress < PIERNIK_INIT_MPI) call die("[units:init_units] MPI not initialized.")

      call units_par_io

      s_lmtvB(U_ENER) = "complex "
      select case (trim(units_set))
         case ("PSM", "psm")
            ! PSM  uses: length --> pc,     mass --> Msun,        time --> myr,        miu0 --> 4*pi,    temperature --> kelvin
            cm       = 1.0/pc_cm            !< centimetre, length unit
            sek      = 1.0/(1.0e6*yr_s)     !< second, time unit
            gram     = 1.0/msun_g           !< gram, mass unit
            s_len_u  = ' [pc]'
            s_time_u = ' [Myr]'
            s_mass_u = ' [M_sun]'
            lmtvB    = [1.0, 1.0, 1.0, 1.0, 1.0]
            s_lmtvB(U_LEN:U_TEMP) = ["pc      ", "Msun    ", "Myr     ", "pc / Myr", "gauss   ", "K       "]

         case ("PLN", "pln")
            ! PLN  uses: length --> AU,     mass --> Mjup,        time --> yr,         miu0 --> 4*pi,    temperature --> kelvin
            cm       = 1.0/au_cm            !< centimetre, length unit
            sek      = 1.0/yr_s             !< second, time unit
            gram     = 1.0/mjup_g           !< gram, mass unit
            s_len_u  = ' [AU]'
            s_time_u = ' [yr]'
            s_mass_u = ' [M_jup]'
            lmtvB    = [1.0, 1.0, 1.0, 1.0, 1.0]
            s_lmtvB(U_LEN:U_TEMP) = ["au     ", "Mjup   ", "yr     ", "au / yr", "gauss  ", "K      "]

         case ("BIN", "bin")
            ! BIN  uses: length --> AU,     mass --> Msun,        time --> yr,         miu0 --> 4*pi,    temperature --> kelvin
            cm       = 1.0/au_cm            !< centimetre, length unit
            sek      = 1.0/yr_s             !< second, time unit
            gram     = 1.0/msun_g           !< gram, mass unit
            s_len_u  = ' [AU]'
            s_time_u = ' [yr]'
            s_mass_u = ' [M_sun]'
            lmtvB    = [1.0, 1.0, 1.0, 1.0, 1.0]
            s_lmtvB(U_LEN:U_TEMP) = ["au     ", "Msun   ", "yr     ", "au / yr", "gauss  ", "K      "]

         case ("KSG", "ksg")
            ! KSG  uses: length --> kpc,    mass --> 10^6*Msun,   time --> Gyr,        miu0 --> 4*pi,    temperature --> kelvin
            cm       = 1.0/(1.0e3*pc_cm)    !< centimetre, length unit
            sek      = 1.0/(1.0e9*yr_s)     !< second, time unit
            gram     = 1.0/(1.0e6*msun_g)   !< gram, mass unit
            s_len_u  = ' [kpc]'
            s_time_u = ' [Gyr]'
            s_mass_u = ' [10^6 M_sun]'
            lmtvB    = [1.0, 1.0e6, 1.0, 1.0, 1.0]
            s_lmtvB(U_LEN:U_TEMP) = ["kpc      ", "Msun     ", "Gyr      ", "kpc / Gyr", "gauss    ", "K        "]

         case ("KSM", "ksm")
            ! KSM  uses: length --> kpc,    mass --> Msun,        time --> myr,        miu0 --> 4*pi,    temperature --> kelvin
            cm       = 1.0/(1.0e3*pc_cm)    !< centimetre, length unit
            sek      = 1.0/(1.0e6*yr_s)     !< second, time unit
            gram     = 1.0/msun_g           !< gram, mass unit
            s_len_u  = ' [kpc]'
            s_time_u = ' [Myr]'
            s_mass_u = ' [M_sun]'
            lmtvB    = [1.0, 1.0, 1.0, 1.0, 1.0]
            s_lmtvB(U_LEN:U_TEMP) = ["kpc      ", "Msun     ", "Myr      ", "kpc / Myr", "gauss    ", "K        "]

         case ("PGM", "pgm")
            ! PGM  uses: length --> pc,     newtong --> 1.0,      time --> myr,        miu0 --> 4*pi,    temperature --> kelvin
            cm       = 1.0/pc_cm            !< centimetre, length unit
            sek      = 1.0/(1.0e6*yr_s)     !< second, time unit
            gram     = newton_cgs*cm**3/1.0/sek**2      !< gram, mass unit  G = 1.0
            s_len_u  = ' [pc]'
            s_time_u = ' [Myr]'
            s_mass_u = ' [-> G=1]'
            lmtvB    = [1.0, 1.0 / gram, 1.0, 1.0, 1.0]
            s_lmtvB(U_LEN:U_TEMP) = ["pc      ", "g       ", "Myr     ", "pc / Myr", "gauss   ", "K       "]   ! FIXME

         case ("SSY", "ssy")
            ! SSY  uses: length --> 10^16 cm,  mass --> Msun,     time --> year,       miu0 --> 4*pi,    temperature --> kelvin
            cm       = 1.0/1.0e16           !< centimetre, length unit
            sek      = 1.0/yr_s             !< second, time unit
            gram     = 1.0/msun_g           !< gram, mass unit
            s_len_u  = ' [10^16 cm]'
            s_time_u = ' [yr]'
            s_mass_u = ' [M_sun]'
            lmtvB    = [1.0e16, 1.0, 1.0, 1.0e16, 1.0]
            s_lmtvB(U_LEN:U_TEMP) = ["cm     ", "Msun   ", "yr     ", "cm / yr", "gauss  ", "K      "]

         case ("SI", "si")
            ! SI   uses: length --> metr,   mass --> kg,          time --> sek,        miu0 --> 4*pi,    temperature --> kelvin
            cm       = 1.0/1.0e2            !< centimetre, length unit
            sek      = 1.0                  !< second, time unit
            gram     = 1.0/1.0e3            !< gram, mass unit
            s_len_u  = ' [m]'
            s_time_u = ' [s]'
            s_mass_u = ' [kg]'
            lmtvB    = [1.0, 1.0, 1.0, 1.0, 1.0]
            s_lmtvB  = ["m    ", "kg   ", "s    ", "m / s", "T    ", "K    ", "J    "]    ! FIXME is tesla right?

         case ("CGS", "cgs")
            ! CGS  uses: length --> cm,     mass --> gram,        time --> sek,        miu0 --> 4*pi,    temperature --> kelvin
            cm       = 1.0                  !< centimetre, length unit
            sek      = 1.0                  !< second, time unit
            gram     = 1.0                  !< gram, mass unit
            s_len_u  = ' [cm]'
            s_time_u = ' [s]'
            s_mass_u = ' [g]'
            lmtvB    = [1.0, 1.0, 1.0, 1.0, 1.0]
            s_lmtvB  = ["cm    ", "g     ", "s     ", "cm / s", "gauss ", "K     ", "erg   "]

         case ("WT4", "wt4")
            ! WT4  uses: length --> 6.25AU, mass --> 0.1 M_sun,   time --> 2.5**3.5 /pi years (=> G \approx 1. in Wengen Test #4),
            cm       = 1./(6.25*au_cm)     !< centimetre, length unit
            ! It's really weird that use of 2.5**3.5 here can cause Internal Compiler Error at multigridmultipole.F90:827
            sek      = 1./(24.7052942200655/pi * yr_s) !< year, time unit; 24.7052942200655 = 2.5**3.5
            gram     = 1/(0.1*msun_g)      !< gram, mass unit
            s_len_u  = ' [6.25 AU]'
            s_time_u = ' [2.5**3.5 /pi years]'
            s_mass_u = ' [0.1 M_sun]'
            lmtvB    = [6.25, 0.1, 24.7052942200655 / pi, 6.25 * pi / 24.7052942200655, 1.0]
            s_lmtvB(U_LEN:U_TEMP)  = ["au     ", "Msun   ", "yr     ", "au / yr", "gauss  ", "K      "]

         case ("USER", "user")
            if (master) call warn("[units:init_units] PIERNIK will use 'cm', 'sek', 'gram' defined in problem.par")
            if (any([cm.equals.dirtyL, sek.equals.dirtyL, gram.equals.dirtyL])) &
               call die("[units:init_units] units_set=='user', yet one of {'cm','sek','gram'} is not set in problem.par") ! Don't believe in coincidence
            v = V_INFO               ! Increase verbosity in case someone is not aware what he/she is doing
            if (trim(s_len_u)  == ' undefined') s_len_u   = ' [user unit]'
            if (trim(s_time_u) == ' undefined') s_time_u  = ' [user unit]'
            if (trim(s_mass_u) == ' undefined') s_mass_u  = ' [user unit]'
            lmtvB    = [1.0, 1.0, 1.0, 1.0, 1.0]
            s_lmtvB  = ["dimensionless", "dimensionless", "dimensionless", &
                        "dimensionless", "dimensionless", "dimensionless", "dimensionless"]  ! trick for yt

         case default
            if (master) call warn("[units:init_units] you haven't chosen units set. That means physical vars taken from 'units' are worthless or equal 1")
            cm   = dirtyL
            gram = dirtyL
            sek  = dirtyL

            scale_me = .true.
            lmtvB    = [1.0, 1.0, 1.0, 1.0, 1.0]
            s_lmtvB  = ["dimensionless", "dimensionless", "dimensionless", &
                        "dimensionless", "dimensionless", "dimensionless", "dimensionless"]

      end select

      if (master .and. .not. scale_me) then
         write(msg,'(a,es14.7,a)') '[units:init_units] cm   = ', cm,   trim(s_len_u)
         call printinfo(msg, v)
         write(msg,'(a,es14.7,a)') '[units:init_units] sek  = ', sek,  trim(s_time_u)
         call printinfo(msg, v)
         write(msg,'(a,es14.7,a)') '[units:init_units] gram = ', gram, trim(s_mass_u)
         call printinfo(msg, v)
      endif

! length units:
      metr       = 1.0e2*cm                 !< metre, length unit
      km         = 1.0e5*cm                 !< kilometer, length unit
      au         = au_cm*cm                 !< astronomical unit (length unit)
      pc         = pc_cm*cm                 !< parsec, length unit
      kpc        = 1000.0*pc                !< kiloparsec, length unit
      lyr        = 9.4605e17*cm             !< light year, length unit
! time units:
      minute     = 60.0*sek                 !< minute, time unit
      hour       = 3600.0*sek               !< hour, time unit
      day        = day_s*sek                !< day, time unit
      year       = yr_s*sek                 !< year, time unit
      myr        = 1.0e6*year               !< megayear, time unit
! mass units:
      kg         = 1.0e3*gram               !< kilogram, mass unit
      me         = 9.109558e-28*gram        !< electron mass
      mp         = 1.672614e-24*gram        !< proton mass
      mH         = 1.673559e-24*gram        !< hydrogen atom mass
      amu        = 1.6605391e-24*gram        !< atomic mass unit
      Msun       = msun_g*gram              !< Solar mass, mass unit
      gmu        = 2.32e7*Msun              !< galactic mass unit
! force units:
      newton     = kg*metr/sek**2           !< 1N (SI force unit)
      dyna       = gram*cm/sek**2           !< 1 dyna (cgs force unit)
! energy units:
      joul       = kg*metr**2/sek**2        !< 1J (SI energy unit)
      erg        = gram*cm**2/sek**2        !< 1 erg (cgs energy unit)
      eV         = 1.6022e-12*erg           !< 1 eV
! area (cross section) units:
      barn       = 1.0e-28 * metr**2        !< barn (cross section unit)
      mbarn      = 1.0e-3 * barn            !< milibarn (cross section unit)
! density units:
      ppcm3      = 1.36 * mp / cm**3        !< spatial density unit
      ppcm2      = 1.36 * mp / cm**2        !< column density unit
! temperature units:
      kelvin     = 1.0                      !< kelvin, temperature unit
! physical constants:
      kboltz     = kB_cgs*erg/kelvin        !< boltzmann constant
      gasRconst  = 8.314472e7*erg/kelvin    !< gas constant R =  8.314472e7*erg/kelvin/mol = k_B * N_A
      N_A        = gasRconst / kboltz       !< Avogadro constant
      clight     = 2.99792458e10*cm/sek     !< speed of light in vacuum (IAU 2009)
      sigma_T    = 6.6524587321e-25*cm**2   !< Thomson cross section
      Gs         = sqrt(miu0*gram/cm)/sek   !< 1 Gs (cgs magnetic induction unit)
      mGs        = Gs*1.e-6                 !< 1 microgauss
      Tesla      = 1.e4*Gs                  !< 1 T (SI magnetic induction unit)
      newtong    = newton_cgs*cm**3/gram/sek**2 !< newtonian constant of gravitation
      fpiG       = fpi*newtong              !< four Pi times Newtonian constant of gravitation (commonly used in self-gravity routines)
      planck     = 6.626196e-27*erg*sek     !< Planck constant
      r_gc_sun   = 8.5*kpc                  !< Sun distance from the Galaxy Center
      vsun       = 220.0*km/sek             !< velocity value of Sun in the Galaxy
      sunradius  = 6.9598e10*cm             !< radius of Sun
      u_CMB      = 0.260*eV/cm**3           !< Cosmic Microwave Background energy density at current epoch (from Particle Data Group, 2020)
      Lsun       = 3.826e33*erg/sek         !< luminosity of Sun
      Mearth     = 5.977e27*gram            !< mass of Earth
      earthradius= 6378.17*km               !< radius of Earth
      TempHalo   = 1.0e6*kelvin             !< Initial mass of the halo in Kelvin
      Lambda_C   = 1.65e-16*cm**3/sek       !< Couling term of Coulomb losses for non-spectral CR protons (Guo & Ho, 2008)
      Lambda_Cc  = 1e-18*erg*cm**3/sek     !< Couling term of Coulomb losses for spectral CRs (Girichidis et al, 2020)

      ! Following physical constants are used in various modules.
      ! They need to have some sane values.
      if (scale_me) then
         kboltz    = 1.0  ! dataio
         gasRconst = 1.0  ! dataio
         mH        = 1.0  ! dataio
         fpiG      = fpi  ! multigrid_gravity, poissonsolver
         newtong   = 1.0  ! multigridmultipole, gravity, poissonsolver
      endif

      if (master) then
         write(msg,'(a,es20.13)') '[units:init_units] newtong = ', newtong
         call printinfo(msg, v)
         write(msg,'(a,es20.13)') '[units:init_units] kboltz  = ', kboltz
         call printinfo(msg, v)
      endif

   end subroutine init_units

   subroutine units_par_io

      use bcast,      only: piernik_MPI_Bcast
      use constants,  only: one, fpi, dirtyL
      use dataio_pub, only: nh
      use mpisetup,   only: cbuff, rbuff, master, slave

      implicit none

      namelist /UNITS/ units_set, miu0, kelvin, cm, gram, sek, s_len_u, s_time_u, s_mass_u

      units_set = 'scaled'
      s_len_u   = ' undefined'
      s_time_u  = s_len_u
      s_mass_u  = s_len_u

      miu0   = fpi
      kelvin = one
      cm     = dirtyL
      gram   = dirtyL
      sek    = dirtyL

      if (master) then

         if (.not.nh%initialized) call nh%init()
         open(newunit=nh%lun, file=nh%tmp1, status="unknown")
         write(nh%lun,nml=UNITS)
         close(nh%lun)
         open(newunit=nh%lun, file=nh%par_file)
         nh%errstr=""
         read(unit=nh%lun, nml=UNITS, iostat=nh%ierrh, iomsg=nh%errstr)
         close(nh%lun)
         call nh%namelist_errh(nh%ierrh, "UNITS")
         read(nh%cmdl_nml,nml=UNITS, iostat=nh%ierrh)
         call nh%namelist_errh(nh%ierrh, "UNITS", .true.)
         open(newunit=nh%lun, file=nh%tmp2, status="unknown")
         write(nh%lun,nml=UNITS)
         close(nh%lun)
         call nh%compare_namelist()

         cbuff(1) = units_set
         cbuff(2) = s_len_u
         cbuff(3) = s_time_u
         cbuff(4) = s_mass_u

         rbuff(1) = miu0
         rbuff(2) = kelvin
         rbuff(3) = cm
         rbuff(4) = gram
         rbuff(5) = sek

      endif

      call piernik_MPI_Bcast(cbuff, cbuff_len)
      call piernik_MPI_Bcast(rbuff)

      if (slave) then

         units_set = cbuff(1)
         s_len_u   = cbuff(2)
         s_time_u  = cbuff(3)
         s_mass_u  = cbuff(4)

         miu0   = rbuff(1)
         kelvin = rbuff(2)
         cm     = rbuff(3)
         gram   = rbuff(4)
         sek    = rbuff(5)

      endif

   end subroutine units_par_io

   subroutine get_unit(field, val, s_val)

      use constants, only: U_LEN, U_MASS, U_TIME, U_VEL, U_MAG, U_TEMP, units_len

      implicit none

      character(len=*), intent(in) :: field
      real, intent(out) :: val
      character(len=units_len), intent(out):: s_val

      select case (trim(field))
         case ("dend", "deni", "denn", "density")
            val = lmtvB(U_MASS) / lmtvB(U_LEN) ** 3
            write(s_val, '(a,"/",a,"**3")') trim(s_lmtvB(U_MASS)),trim(s_lmtvB(U_LEN))
         case ("vlxd", "vlxn", "vlxi", "vlyd", "vlyn", "vlyi", "vlzd", "vlzn", "vlzi", "velocity_x", "velocity_y", "velocity_z")
            val = lmtvB(U_VEL)
            write(s_val, '(a)') trim(s_lmtvB(U_VEL))
         case ("enen", "enei", "energy_density")
            val = lmtvB(U_MASS) / lmtvB(U_LEN) / lmtvB(U_TIME) ** 2
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, "/",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("ethn", "ethi", "specific_energy")
            val = lmtvB(U_LEN) ** 2 / lmtvB(U_TIME) ** 2
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a)') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_MASS))
            else
               write(s_val, '(a, "**2 /",a,"**2")') trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("pren", "prei", "pressure")
            val =  lmtvB(U_MASS) / lmtvB(U_LEN) / lmtvB(U_TIME) ** 2
            write(s_val, '(a, "/", a, "/",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
         case ("temn", "temi", "temperature")
            val =  1.0
            write(s_val, '(a)') trim(s_lmtvB(U_TEMP))
         case ("magx", "magy", "magz")
            val = lmtvB(U_MAG)
            write(s_val, '(a)') trim(s_lmtvB(U_MAG))

         !case ("cr01" : "cr99", "cr_A000" : "cr_zz99", "cree01" : "cree99")
         !   val = lmtvB(U_MASS) / lmtvB(U_LEN) / lmtvB(U_TIME) ** 2
         !   if (trim(s_lmtvB(U_ENER)) /= "complex") then
         !      write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
         !   else
         !      write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
         !   endif
#ifdef CRESP
         case ("cr_e-n01" : "cr_e-n99") !< CRESP rest mass times number density
             if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
           !  val = 1.0 / lmtvB(U_LEN)**3                             !< CRESP number density
           !  write(s_val, '( "1  /", a,"**3")') trim(s_lmtvB(U_LEN))
         case ("cr_e-e01" : "cr_e-e99")
             if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_p+n01" : "cr_p+n99") !< CRESP rest mass times number density
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_p+e01" : "cr_p+e99")
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_C12n01" : "cr_C12n99") !< CRESP rest mass times number density
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_C12e01" : "cr_C12e99")
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_N14n01" : "cr_N14n99") !< CRESP rest mass times number density
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_N14e01" : "cr_N14e99")
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_O16n01" : "cr_O16n99") !< CRESP rest mass times number density
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_O16e01" : "cr_O16e99")
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_Li7n01" : "cr_Li7n99") !< CRESP rest mass times number density
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_Li7e01" : "cr_Li7e99")
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_Be9n01" : "cr_Be9n99") !< CRESP rest mass times number density
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_Be9e01" : "cr_Be9e99")
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_Be10n01" : "cr_Be10n99") !< CRESP rest mass times number density
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_Be10e01" : "cr_Be10e99")
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_B10n01" : "cr_B10n99") !< CRESP rest mass times number density
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_B10e01" : "cr_B10e99")
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_B11n01" : "cr_B11n99") !< CRESP rest mass times number density
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
         case ("cr_B11e01" : "cr_B11e99")
            if (trim(s_lmtvB(U_ENER)) /= "complex") then
               write(s_val, '(a, "/", a,"**3")') trim(s_lmtvB(U_ENER)), trim(s_lmtvB(U_LEN))
            else
               write(s_val, '(a, "/", a, " /",a,"**2")') trim(s_lmtvB(U_MASS)), trim(s_lmtvB(U_LEN)), trim(s_lmtvB(U_TIME))
            endif
#endif /* CRESP */
         case ("gpot", "sgpt")
            val = lmtvB(U_VEL) ** 2
            write(s_val, '(a,"**2")') trim(s_lmtvB(U_VEL))
         case default
            val = 1.0
            s_val = "dimensionless"
      end select
      return
   end subroutine get_unit

end module units
