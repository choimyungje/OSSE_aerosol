module GEMSTOOL_RTCALC_m

!  Rob Fix, 10/18/16. Introduced SIF
!    GEMSTOOL_RTCALC_Actual - SIF inputs added, VLIDORT variables set
!    GEMSTOOL_RTCALC_Final  - No changes

!  Rob Fix, 10/25/16. Introduced BRDF
!    GEMSTOOL_RTCALC_Actual - BRDF inputs added, VLIDORT variables set
!    GEMSTOOL_RTCALC_Final  - No changes

!  Rob Fix, 10/25/16. SLEAVE Structure replace SIF (more general, allows for water-leaving)

!  Rob Fix, 11/30/16. Allowing for linear parameterization of SIF.

!  Module files for VLIDORT

   USE VLIDORT_PARS
   USE VLIDORT_IO_DEFS
   USE VLIDORT_MASTERS

!  Module files for the BRDF and SLEAVE inputs. Added 10/25/16.

   USE VBRDF_SUP_MOD
   USE VSLEAVE_SUP_MOD

public  :: GEMSTOOL_RTCALC_Actual, GEMSTOOL_RTCALC_Final
private :: makechar3

contains

subroutine GEMSTOOL_RTCALC_Actual &
    ( VLIDORT_FixIn, VLIDORT_ModIn, VLIDORT_Sup, Polynomial, SIF_ExactOnly, & ! VLIDORT Actual inputs, SIF
      nlayers, NGREEK_MOMENTS_INPUT, HEIGHT_GRID, lambertian_albedo,        & ! Control Proxies
      DELTAU_VERT_INPUT, OMEGA_TOTAL_INPUT, GREEKMAT_TOTAL_INPUT,           & ! Atmos-Optical Proxies
      GEMSTOOL_SLEAVE_Results, GEMSTOOL_BRDF_Results,                       & ! Surface Supplement Results
      VLIDORT_Out )                                                           ! VLIDORT output results

   implicit none

!  precision

   integer, parameter :: fpk = SELECTED_REAL_KIND(15)

!  First order flags

!   logical, INTENT(IN) :: do_firstorder_option  ! turn on, using new FO code
!   logical, INTENT(IN) :: FO_do_regular_ps      ! turn on, using FO code regular PS mode

!  VLIDORT settings structure, Intent(out) here

   TYPE(VLIDORT_Fixed_Inputs), INTENT(INOUT)       :: VLIDORT_FixIn
   TYPE(VLIDORT_Modified_Inputs), INTENT(INOUT)    :: VLIDORT_ModIn

!  VLIDORT supplements i/o structure

   TYPE(VLIDORT_Sup_InOut), INTENT(INOUT)          :: VLIDORT_Sup

!  11/30/16. Add SIF Polynomial factor (Equal to 1.0 unless SIF linear parameterization)
!  11/30/16. Add SIF Exact-only approximation option

   REAL(fpk), intent(in) :: Polynomial
   Logical  , intent(in) :: SIF_ExactOnly

!  Proxy inputs for VLIDORT

   INTEGER, intent(in)      :: NLAYERS
   INTEGER, intent(in)      :: NGREEK_MOMENTS_INPUT

   REAL(fpk), intent(in) :: HEIGHT_GRID           ( 0:MAXLAYERS )
   REAL(fpk), intent(in) :: DELTAU_VERT_INPUT     ( MAXLAYERS )
   REAL(fpk), intent(in) :: OMEGA_TOTAL_INPUT     ( MAXLAYERS )
   REAL(fpk), intent(in) :: GREEKMAT_TOTAL_INPUT  ( 0:MAXMOMENTS_INPUT, MAXLAYERS, MAXSTOKES_SQ )
   REAL(fpk), intent(in) :: LAMBERTIAN_ALBEDO

!  10/18/16. SIF array added

!  SLEAVE input structure, added 10/25/16. FIrst Attempt was only for SIF....
!   REAL(fpk), intent(in) :: GEMSTOOL_SIF          ( MAX_GEOMETRIES )

   TYPE(VSLEAVE_Sup_Outputs), INTENT(IN) :: GEMSTOOL_SLEAVE_Results

!  BRDF input structure, added 10/25/16

   TYPE(VBRDF_Sup_Outputs),   INTENT(IN) :: GEMSTOOL_BRDF_Results

!  VLIDORT output structure

   TYPE(VLIDORT_Outputs), intent(inout)  :: VLIDORT_Out

!  Local. Additional quantities for SIF, 10/18/16.

   logical, parameter :: skip_vlidort = .false.
   integer   :: jj, g, L, nstreams, nmoments, ngeoms
   real(fpk) :: Iso_Value

!  START Of CODE
!  =============

!  Set Final VLIDORT inputs from the PROXIES
!  -----------------------------------------

   VLIDORT_FixIn%Cont%TS_NLAYERS                  = NLAYERS
   VLIDORT_FixIn%Chapman%TS_HEIGHT_GRID           = HEIGHT_GRID
   VLIDORT_ModIn%MUserVal%TS_GEOMETRY_SPECHEIGHT  = HEIGHT_GRID(NLAYERS)

   VLIDORT_ModIn%MCont%TS_NGREEK_MOMENTS_INPUT    = NGREEK_MOMENTS_INPUT
   VLIDORT_FixIn%Optical%TS_DELTAU_VERT_INPUT     = DELTAU_VERT_INPUT
   VLIDORT_ModIn%MOptical%TS_OMEGA_TOTAL_INPUT    = OMEGA_TOTAL_INPUT
   VLIDORT_FixIn%Optical%TS_GREEKMAT_TOTAL_INPUT  = GREEKMAT_TOTAL_INPUT
   VLIDORT_FixIn%Optical%TS_LAMBERTIAN_ALBEDO     = LAMBERTIAN_ALBEDO     ! May be zero if BRDF in effect

!  proxies

   ngeoms   = VLIDORT_ModIn%MUserVal%TS_N_USER_OBSGEOMS
   nstreams = VLIDORT_FixIn%Cont%TS_NSTREAMS
   nmoments = 2 * nstreams

!  Surface-leaving inputs
!  ----------------------

!  10/18/16, 10/25/16. Here is where you set the VLIDORT inputs
!     Only operating with unpolarized stuff (JJ = 1, indicates first Stokes component
!         VLIDORT supplement arrays are pre-zeroed.

!  11/30/16. Upgrade to include linear parameterization of Fluorescence
!    -- if flagged apply polynomial to basic 755 result.
!    -- Use of the Exact-only approximation to SI is in force.

   JJ = 1
   if ( VLIDORT_FixIn%Bool%TS_DO_SURFACE_LEAVING ) THEN
      if ( VLIDORT_FixIn%Bool%TS_DO_SL_ISOTROPIC ) THEN
         do g = 1, ngeoms
            Iso_Value = Polynomial * GEMSTOOL_SLEAVE_Results%SL_SLTERM_ISOTROPIC(JJ,g)
            VLIDORT_Sup%SLEAVE%TS_SLTERM_ISOTROPIC(JJ,g)        = Iso_Value
            VLIDORT_Sup%SLEAVE%TS_SLTERM_USERANGLES(JJ,g,g,g)   = Iso_Value
            if ( .not. SIF_ExactOnly ) then
               VLIDORT_Sup%SLEAVE%TS_SLTERM_F_0(0,JJ,1:nstreams,g) = Iso_Value
               VLIDORT_Sup%SLEAVE%TS_USER_SLTERM_F_0(0,JJ,g,g)     = Iso_Value
            endif
         enddo
      else ! This is rather academic as fluorescence is isotropic......
         do g = 1, ngeoms
            VLIDORT_Sup%SLEAVE%TS_SLTERM_ISOTROPIC(JJ,g)        = &
                          Polynomial * GEMSTOOL_SLEAVE_Results%SL_SLTERM_ISOTROPIC(JJ,g)
            VLIDORT_Sup%SLEAVE%TS_SLTERM_USERANGLES(JJ,g,g,g)   = &
                          Polynomial * GEMSTOOL_SLEAVE_Results%SL_SLTERM_USERANGLES(JJ,g,g,g)
            if ( .not. SIF_ExactOnly ) then
               do L = 0, nmoments
                  VLIDORT_Sup%SLEAVE%TS_SLTERM_F_0(L,JJ,1:nstreams,g) = &
                          Polynomial * GEMSTOOL_SLEAVE_Results%SL_SLTERM_F_0(L,JJ,1:nstreams,g)
                  VLIDORT_Sup%SLEAVE%TS_USER_SLTERM_F_0(L,JJ,g,g)     = &
                          Polynomial * GEMSTOOL_SLEAVE_Results%SL_USER_SLTERM_F_0(0,JJ,g,g) 
               enddo
            endif
         enddo
      endif
   endif

!  BRDF inputs. 10/25/16. Copy the GEMSTOOL_BRDF_Results variables to VLIDORT
!   VBRDF inputs are all pre-initialized; emissivities not requird

   if ( .not.VLIDORT_FixIn%Bool%TS_DO_LAMBERTIAN_SURFACE ) THEN 
      VLIDORT_Sup%BRDF%TS_BRDF_F_0        = GEMSTOOL_BRDF_Results%BS_BRDF_F_0
      VLIDORT_Sup%BRDF%TS_BRDF_F          = GEMSTOOL_BRDF_Results%BS_BRDF_F
      VLIDORT_Sup%BRDF%TS_USER_BRDF_F_0   = GEMSTOOL_BRDF_Results%BS_USER_BRDF_F_0
      VLIDORT_Sup%BRDF%TS_USER_BRDF_F     = GEMSTOOL_BRDF_Results%BS_USER_BRDF_F
      VLIDORT_Sup%BRDF%TS_EXACTDB_BRDFUNC = GEMSTOOL_BRDF_Results%BS_DBOUNCE_BRDFUNC
   endif

! SANITY CHECK, 27 July 2013
!   write(*,*)VLIDORT_FixIn%Cont%TS_NSTREAMS
!   write(*,*)VLIDORT_ModIn%MCont%TS_NGREEK_MOMENTS_INPUT
!   write(*,*)VLIDORT_FixIn%Sunrays%TS_FLUX_FACTOR
!   write(*,*)VLIDORT_ModIn%MBool%TS_DO_RAYLEIGH_ONLY
!   write(*,*)VLIDORT_ModIn%MBool%TS_DO_DELTAM_SCALING
!   write(*,*) VLIDORT_ModIn%MBool%TS_DO_SSCORR_NADIR
!   write(*,*) VLIDORT_ModIn%MBool%TS_DO_SSCORR_OUTGOING
!   write(*,*) VLIDORT_ModIn%MBool%TS_DO_OBSERVATION_GEOMETRY
!   write(*,*)VLIDORT_ModIn%MUserVal%TS_N_USER_OBSGEOMS
!   write(*,*)VLIDORT_ModIn%MUserVal%TS_USER_OBSGEOMS_INPUT
!   write(*,*)VLIDORT_FixIn%Cont%TS_NLAYERS
!   write(*,*)VLIDORT_FixIn%Optical%TS_DELTAU_VERT_INPUT
!   write(*,*)VLIDORT_FixIn%Chapman%TS_HEIGHT_GRID
!   write(*,*)VLIDORT_FixIn%Optical%TS_GREEKMAT_TOTAL_INPUT
!   write(*,*)VLIDORT_FixIn%Bool%TS_DO_UPWELLING
!   write(*,*)VLIDORT_FixIn%Bool%TS_DO_DNWELLING
!   write(*,*)VLIDORT_FixIn%UserVal%TS_N_USER_LEVELS
   ! write(*,*)VLIDORT_ModIn%MUserVal%TS_USER_LEVELS(1)
   ! write(*,*)VLIDORT_ModIn%MUserVal%TS_USER_LEVELS(2)
! pause

!  Perform the VLIDORT calculation

   if (skip_vlidort) then
      VLIDORT_Out%Main%TS_Stokes = 1.0d0
      VLIDORT_Out%Status%TS_STATUS_INPUTCHECK  = 0
      VLIDORT_Out%Status%TS_NCHECKMESSAGES     = 0
      VLIDORT_Out%Status%TS_CHECKMESSAGES      = ' '
      VLIDORT_Out%Status%TS_ACTIONS            = ' '
      VLIDORT_Out%Status%TS_STATUS_CALCULATION = 0
      VLIDORT_Out%Status%TS_MESSAGE            = ' '
      VLIDORT_Out%Status%TS_TRACE_1            = ' '
      VLIDORT_Out%Status%TS_TRACE_2            = ' '
      VLIDORT_Out%Status%TS_TRACE_3            = ' '
   else
      CALL vlidort_master( &
           VLIDORT_FixIn, &
           VLIDORT_ModIn, &
           VLIDORT_Sup,   &
           VLIDORT_Out )
   end if

!  Finish

   return
end subroutine GEMSTOOL_RTCALC_Actual

subroutine GEMSTOOL_RTCALC_Final &
   (  MAXWAV, maxmessages, W, do_SphericalAlbedo, & ! GEMSTOOL control
      nstokes, n_geometries, dir, VLIDORT_Out,    & ! VLIDORT Results
      STOKES, ACTINIC, REGFLUX, DOLP, DOCP,       & ! Main program, GEMSTOOL Results
      Errorstatus, nmessages, messages )            ! Main program, exception handling

   implicit none

!  precision

   integer, parameter :: fpk = SELECTED_REAL_KIND(15)

!  Inputs
!  ------

!  GEMSTOOL wavelength and MAX-Messages dimensions

   integer, intent(in) :: MAXWAV, maxmessages

!  wavelength point

   integer, intent(in) :: w

!  Proxy control inputs

   integer, intent(in) :: nstokes, n_geometries

!  Flux control flag (GEMSTOOL control)

   logical, intent(in) :: do_SphericalAlbedo

!  Direction (TOA upwelling = 1, BOA downwelling = 2)

   integer, intent(in) :: dir

!  VLIDORT output structure

   TYPE(VLIDORT_Outputs), intent(in)   :: VLIDORT_Out

!  Output arrays
!  =============

!  Radiances
      
   real(fpk)   , DIMENSION (MAX_GEOMETRIES,4,MAXWAV)      :: STOKES

!  Degree of linear/circular polarization (DOLP/DOCP)

   real(fpk)   , DIMENSION (MAX_GEOMETRIES,MAXWAV)        :: DOLP
   real(fpk)   , DIMENSION (MAX_GEOMETRIES,MAXWAV)        :: DOCP

!  Actinic and Regular Flux output

   real(fpk)   , DIMENSION (MAX_GEOMETRIES,4,MAXWAV)      :: ACTINIC
   real(fpk)   , DIMENSION (MAX_GEOMETRIES,4,MAXWAV)      :: REGFLUX

!  Exception handling
!    ( Errorstatus = 0 = SUCCCESS,  Errorstatus = 1 = FAILURE,  Errorstatus = 2 = WARNING )

   integer         , intent(out)     ::  Errorstatus
   integer         , intent(inout)   ::  nmessages
   CHARACTER(LEN=*), intent(inout)   ::  messages(maxmessages)

!  Local

   real(fpk)           :: sq2u2, sv2
   integer             :: nm, v, o1, n, nc
   character(LEN=3)    :: c3

!  Initialization

   STOKES (:,:,W) = ZERO
   ACTINIC(:,:,W) = ZERO
   REGFLUX(:,:,W) = ZERO
   DOLP   (:,W)   = ZERO
   DOCP   (:,W)   = ZERO

!  Exception handling

   NM = Nmessages
   Errorstatus = 0

!  Input check - failure in VLIDORT

   if ( VLIDORT_Out%Status%TS_status_inputcheck.eq.vlidort_serious ) then
      call makechar3(w,c3)
      messages(nm + 1) = 'vlidort input check, failed for wavelength # '//c3
      messages(nm + 2) = 'vlidort will not execute, here are the Input Check messages and Actions:--'
      nm = nm + 2
      nc = VLIDORT_Out%Status%TS_NCHECKMESSAGES
      DO N = 1, VLIDORT_Out%Status%TS_NCHECKMESSAGES
         call makechar3(n,c3)
         messages(nm + 2*n-1) = ' VLIDORT Message # '//C3//' : '// &
                            adjustl(trim(VLIDORT_Out%Status%TS_CHECKMESSAGES(N)))
         messages(nm + 2*n)   = ' VLIDORT Action  # '//C3//' : '// &
                            adjustl(trim(VLIDORT_Out%Status%TS_ACTIONS(N)))
      ENDDO
      nm = nm + 2*nc
      nmessages = nm ; Errorstatus = 1 ; return
   endif

!  Input check - Warning in VLIDORT, which will go on to Execute

   if ( VLIDORT_Out%Status%TS_status_inputcheck.eq.vlidort_serious ) then
      call makechar3(w,c3)
      messages(nm + 1) = 'vlidort input check, Warning for wavelength # '//c3
      messages(nm + 2) = 'vlidort will carry on with defaults; here are Input Check messages and Actions:--'
      nm = nm + 2
      nc = VLIDORT_Out%Status%TS_NCHECKMESSAGES
      DO N = 1, VLIDORT_Out%Status%TS_NCHECKMESSAGES
         call makechar3(n,c3)
         messages(nm + 2*n-1) = ' VLIDORT Message # '//C3//' : '// &
                            adjustl(trim(VLIDORT_Out%Status%TS_CHECKMESSAGES(N)))
         messages(nm + 2*n)   = ' VLIDORT Action  # '//C3//' : '// &
                            adjustl(trim(VLIDORT_Out%Status%TS_ACTIONS(N)))
      ENDDO
      nm = nm + 2*nc
      nmessages = nm ; Errorstatus = 2
   endif

!  Execution - failure in VLIDORT

   if ( VLIDORT_Out%Status%TS_status_calculation.eq.vlidort_serious ) then
      call makechar3(w,c3)
      messages(nm + 1) = 'vlidort execution, failed for wavelength # '//c3
      messages(nm + 2) = 'here are the Execution-failure messages :--'
      nm = nm + 2
      messages(nm + 1) = ' VLIDORT Execution Message : '//adjustl(trim(VLIDORT_Out%Status%TS_MESSAGE))
      messages(nm + 2) = ' VLIDORT Execution Trace 1 : '//adjustl(trim(VLIDORT_Out%Status%TS_TRACE_1))
      messages(nm + 3) = ' VLIDORT Execution Trace 2 : '//adjustl(trim(VLIDORT_Out%Status%TS_TRACE_2))
      messages(nm + 4) = ' VLIDORT Execution Trace 3 : '//adjustl(trim(VLIDORT_Out%Status%TS_TRACE_3))
      nm = nm + 4
      nmessages = nm ; Errorstatus = 1 ; return
   endif

!  CARRY ON with CALCULATION (Errorstatus = 0 or 2)
!  ------------------------------------------------

!  Loop over geometries and Number of stokes parameters

   DO V = 1, N_GEOMETRIES
      DO O1 = 1, NSTOKES
         STOKES(V,O1,W) = VLIDORT_Out%Main%TS_STOKES(1,V,O1,DIR)
         
         ! write(*,*)VLIDORT_Out%Main%TS_STOKES(1,V,O1,DIR)
         ! write(*,*)VLIDORT_Out%Main%TS_STOKES(2,V,O1,DIR)
         ! pause
      ENDDO
   ENDDO

!  Flux Output: Loop over solar_angles and Number of stokes parameters

   if ( do_SphericalAlbedo ) then
      DO V = 1, N_GEOMETRIES
         DO O1 = 1, NSTOKES
             ACTINIC(V,O1,W) = VLIDORT_Out%Main%TS_MEAN_STOKES(1,V,O1,DIR)
             REGFLUX(V,O1,W) = VLIDORT_Out%Main%TS_FLUX_STOKES(1,V,O1,DIR)
         ENDDO
      ENDDO
   endif

!  Set DOLP to zero if no polarization (Nstokes = 1), and skip DOLP calculation
!         degree of polarization (only for NSTOKES = 3 or 4)

   IF ( NSTOKES.gt.1 ) THEN
      DO V = 1, N_GEOMETRIES
             !------------------------------------- DOLP and DOCP calculation
         SQ2U2 = SQRT(VLIDORT_Out%Main%TS_STOKES(1,V,2,DIR)*VLIDORT_Out%Main%TS_STOKES(1,V,2,DIR) + &
                      VLIDORT_Out%Main%TS_STOKES(1,V,3,DIR)*VLIDORT_Out%Main%TS_STOKES(1,V,3,DIR))
         DOLP(V,W) = SQ2U2 / VLIDORT_Out%Main%TS_STOKES(1,V,1,DIR)
         if ( nstokes .eq. 4 ) then
            SV2 = SQRT(VLIDORT_Out%Main%TS_STOKES(1,V,4,DIR)*VLIDORT_Out%Main%TS_STOKES(1,V,4,DIR))
            DOCP(V,W) = SV2 / VLIDORT_Out%Main%TS_STOKES(1,V,1,DIR)
         endif
      ENDDO
   ENDIF

!  End subroutine

   return
end subroutine GEMSTOOL_RTCALC_Final

subroutine makechar3(w,c3)
  implicit none
  integer, intent(in)          :: w
  character(LEN=3),intent(out) :: c3
  c3 = '000'
  if ( w.lt.10 ) then
     write(c3(3:3),'(I1)')W
  else if ( w.gt.99 ) then
     write(c3(1:3),'(I3)')W
  else
     write(c3(2:3),'(I2)')W
  endif
end subroutine makechar3

!  End module

end module GEMSTOOL_RTCALC_m
