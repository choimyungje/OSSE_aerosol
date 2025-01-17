Module GEMSTOOL_AerProperties_m

!  Use Type structures (GEMSTOOL)

   use GEMSTOOL_Input_Types_m

!  Use Loading routines
!  --------------------

   use GEMSTOOL_aerload_routines_m

!  Use Mie code
!  ------------

!  parameters

   use RTSMie_parameters_m

!  Single call

   use RTSMie_sourcecode_m

!  Bimodal call

   use RTSMie_master_bimodal_m

!  Use Tmatrix code
!  ----------------

!  parameters

   use tmat_parameters

!  Single call

   use tmat_master_m

!  Bimodal call

   use tmat_master_bimodal_m

!  All routines are public

private
public :: GEMSTOOL_AER_PROPERTIES

contains
!        PSD_Index, PSD_pars, n_real, n_imag, FixR1R2, R1, R2, epsnum, epsfac,   & ! INPUT, Mie/Tmat Parameters

subroutine GEMSTOOL_AER_PROPERTIES &
      ( maxlayers, maxwav, maxaermoms,                                                    & ! Dimensions
        interpolate_aerosols, do_wavnums, FDAer, FDLay, FDeps,                            & ! Flags and FD control
        nlayers, nmuller, nwav, wav, height_grid, GEMSTOOL_INPUTS, momsize_cutoff,        & ! Inputs
        aerlayerflags, Loading, n_scatmoms, aertau_unscaled, aod_scaling,                 & ! OUTPUT, aerosol optical properties
        aerosol_deltau, aerosol_ssalbs, aerosol_scatmoms, aerosol_distchars,              & ! OUTPUT, aerosol optical properties
        fail1, fail2, Message_Loading, Messages_Optical )                                   ! Exception handling

!  =============================================================================
!                            AEROSOL REGULAR CREATION
!  =============================================================================

!  aerosol Loading:
!    Loading = optical depth profile
!    Loading Jacobians (Not used here)
!       Cases 1-3 : dloading_Dtau      = derivative of profile w.r.t the total aerosol optical depth at wavelength w0
!       Case 2    : dloading_Dpars(1)  = derivative of profile w.r.t the relaxation parameter (Exponential)
!       Case 3    : dloading_Dpars(1)  = derivative of profile w.r.t the GDF Peak height
!       Case 3    : dloading_Dpars(2)  = derivative of profile w.r.t the GDF Half Width 

!  Generation of Aerosol optical properties
!     1. Call to the Mie/Tmatrix program
!     2. Convert Mie/Tmatrix output (Microsopic) to IOP output (macroscopic) 

   implicit none

!  Precision

   integer, parameter :: fpk = SELECTED_REAL_KIND(15)
  
!  Input variables
!  ---------------

!  External Dimensioning

   integer, INTENT (IN) :: maxlayers, maxwav
   integer, INTENT (IN) :: maxaermoms

!  Flag for interpolation of aerosols

   logical, INTENT(in)  :: interpolate_aerosols

!  Flag for using wavnumber output

   logical, INTENT(in)  :: do_wavnums

!  FD perturbation control

   logical  , INTENT(in)  :: FDAer
   integer  , INTENT(in)  :: FDLay
   REAL(fpk), INTENT (IN) :: FDeps

!  Numbers

   integer, INTENT (IN) ::  nlayers
   integer, INTENT (IN) ::  nwav

!  Heights and wavelengths

   REAL    (fpk),    INTENT (IN)   :: wav(maxwav)
   REAL    (fpk),    INTENT (IN)   :: height_grid(0:maxlayers)

!  nmuller = 1 (scalar code), = 6 (vector code)

   integer, INTENT (IN) ::  nmuller

!  Aerosol moment size cutoff. DEFAULT = 0.001

   REAL    (fpk),    INTENT (IN)   :: momsize_cutoff

!  Type Structure inputs

   TYPE(GEMSTOOL_Config_Inputs) :: GEMSTOOL_INPUTS

!  Mie/Tmatrix PSD inputs
!  ======================

!  PSD inputs (distribution index, PSD parameters)

!      psd_Index      - Index for particle size distribution of spheres
!      psd_pars       - Parameters characterizing PSD (up to 3 allowed)

!    PSD_index = 1 : TWO-PARAMETER GAMMA with alpha and b given
!    PSD_index = 2 : TWO-PARAMETER GAMMA with par(1)= reff and par(2)= veff given
!    PSD_index = 3 : BIMODAL GAMMA with equal mode weights
!    PSD_index = 4 : LOG-NORMAL with rg and sigma given
!    PSD_index = 5 : LOG-NORMAL with reff and veff given
!    PSD_index = 6 : POWER LAW
!    PSD_index = 7 : MODIFIED GAMMA with alpha, rc and gamma given
!    PSD_index = 8 : MODIFIED GAMMA with alpha, b and gamma given

!  FixR1R2 : If  set, Use Internal routine to calculate R1 and R2 (outputs)
!            If Not set, Use Input R1 and R2 for PSD limits.
!  R1, R2         - Minimum and Maximum radii (Microns)
!  N_REAL, N_IMAG - real and imaginary parts, refractive index (N-i.GE.0)

!  Mie-specific inputs
!  ===================

!  Limiting particle size value. Set to 10000.0 default.
!   If you exceed this, program will tell you to increase dimensioning.

!  R1R2_cutoff particle size for setting R1 and R2 internally

!  PSD quadrature control
!    PSD integration ranges is divided into so many blocks.
!    For each block, integrate using Gaussian quadrature, with so many weights.

!  Tmatrix-specific inputs
!  =======================

!  Logical flag for using equal-surface-area sepcification

!      NKMAX.LE.988 is such that NKMAX+2 is the                        
!           number of Gaussian quadrature points used in               
!           integrating over the size distribution for particles
!           MKMAX should be set to -1 for Monodisperse

!      NDGS - parameter controlling the number of division points      
!             in computing integrals over the particle surface.        
!             For compact particles, the recommended value is 2.       
!             For highly aspherical particles larger values (3, 4,...) 
!             may be necessary to obtain convergence.                  
!             The code does not check convergence over this parameter. 
!             Therefore, control comparisons of results obtained with  
!             different NDGS-values are recommended.

!      EPS (Shape_factor) and NP (Spheroid type) - specify the shape of the particles.                
!             For spheroids NP=-1 and EPS is the ratio of the          
!                 horizontal to rotational axes.  EPS is larger than   
!                 1 for oblate spheroids and smaller than 1 for       
!                 prolate spheroids.                                   
!             For cylinders NP=-2 and EPS is the ratio of the          
!                 diameter to the length.                              
!             For Chebyshev particles NP must be positive and 
!                 is the degree of the Chebyshev polynomial, while     
!                 EPS is the deformation parameter                     

!      Accuracy       - accuracy of the computations

!  output
!  ======

!  Loading output

    real(fpk),    dimension ( maxlayers ),  INTENT (OUT)      :: Loading

!  aerosol layer flags

    LOGICAL,      DIMENSION ( maxlayers ), intent(out)  :: AERLAYERFLAGS 

!  AOP output: Number of exapnsion coefficients to be used

   integer, INTENT (OUT)   ::  n_scatmoms

!  Unscaled profiles of optical depth

    real(fpk),    INTENT (OUT)  :: aertau_unscaled(maxlayers)

!  AOD scaling

    real(fpk),    INTENT (OUT)  :: aod_scaling(maxwav)

!  Aod output, final

    REAL(fpk),    DIMENSION( maxlayers, maxwav )      , INTENT (OUT)  :: AEROSOL_DELTAU

!  AOPS

    REAL(fpk),    DIMENSION( maxwav )                 , INTENT (OUT)  :: AEROSOL_SSALBS 
    REAL(fpk),    DIMENSION( 6, 0:maxaermoms, maxwav ), INTENT (OUT)  :: AEROSOL_SCATMOMS

!  Aerosol distribution characterisstics, ONLY FOR THE REFERENCE WAVELENGTH
!    1 = Normalization
!    2 = Cross-section
!    3 = Volume
!    4 = REFF
!    5 = VEFF
   real(fpk),     DIMENSION( 5, 2 )           , INTENT (OUT)  :: AEROSOL_DISTCHARS

!  Exception handling

   logical,        INTENT (OUT)           :: fail1, fail2
   character*(*),  INTENT (OUT)           :: message_Loading(3)
   character*(*),  INTENT (OUT)           :: Messages_Optical(5)

!  LOCAL VARIABLES
!  @@@@@@@@@@@@@@@

!  Loading derivatives (NOT REQUIRED for OUTPUT, here)

    real(fpk),    dimension ( maxlayers )      :: DLoading_Dtau
    real(fpk),    dimension ( maxlayers, 2 )   :: Dloading_Dpars

!  Mie/Tmatrix LOCAL INPUT variables (Not part of module input)
!  ============================================================

!      Do_Expcoeffs      - Boolean flag for computing Expansion Coefficients
!      Do_Fmatrix        - Boolean flag for computing F-matrix at equal-angles

   logical    :: Do_Expcoeffs
   logical    :: Do_Fmatrix

!      Do_Monodisperse   - Boolean flag for Doing a Monodisperse calculation
!                          If set, the PSD stuff will be turned off internally

   LOGICAL    :: do_Monodisperse

!  F-matrix Angular control input (NOT REQUIRED HERE)

!  Calculate F-matrix at user-defined angles (do_Fmatrix flag MUST BE set)
!       n_Fmatrix_angles = number of user-defined angles. (NPNA)
!       Fmatrix_angles   = user-defined angles, in DEGREES between [0, 180]

!  NPNA - number of equidistant scattering angles (from 0
!             to 180 deg) for which the scattering matrix is
!             calculated.

!    NOT REQUIRED HERE

   INTEGER           :: n_Fmatrix_angles
   REAL    (fpk)     :: Fmatrix_angles(max_Mie_angles)

!  Monoradius     - Monodisperse radius size (Microns)

   real    (fpk)     :: Monoradius

!  (Tmatrix only). Style flag.
!    * This is checked and re-set (if required) for Monodisperse case

   logical           :: Do_psd_OldStyle

!  Mie code OUTPUT variables
!  =========================

!  Bulk distribution parameters
!    1 = Extinction coefficient
!    2 = Scattering coefficient
!    3 = Single scattering albedo

   real(fpk)    :: BMie_bulk (3)

!  Expansion coefficients and Asymmetry parameter

   integer      :: BMie_ncoeffs
   real(fpk)    :: BMie_expcoeffs (6,0:max_Mie_angles)
   real(fpk)    :: BMie_asymm

!  F-matrix,  optional output

   real(fpk)    :: BMie_Fmatrix(4,max_Mie_angles)

!  Distribution parameters
!    1 = Normalization
!    2 = Cross-section
!    3 = Volume
!    4 = REFF
!    5 = VEFF

   real(fpk)     :: BMie_dist (5,2)

!  Exception handling

   character*90  :: Mie_Bmessages(3)
   character*90  :: Mie_trace_3

!  Tmatrix code OUTPUT variables (Notation similar)
!  =============================

!  Bulk distribution parameters

   real(fpk)    :: BTmat_bulk (3)

!  Expansion coefficients and Asymmetry parameter

   integer      :: BTmat_ncoeffs
   real(fpk)    :: BTmat_expcoeffs (NPL1,6)
   real(fpk)    :: BTmat_asymm

!  F-matrix,  optional output

   real(fpk)    :: BTmat_Fmatrix(MAXNPA,6)

!  Distribution parameters

   real(fpk)     :: BTmat_dist (5,2)

!  Exception handling

   character*90  :: Tmat_message
   character*90  :: Tmat_trace
   character*90  :: Tmat_trace_2
   character*90  :: Tmat_trace_3

!  Local variables
!  ===============

!  Local aerosol properties ! New, @@@ RTS 09/11/12

!   integer   :: PSD_index(2)              ! New, @@@ RTS 09/11/12
!   real(fpk) :: PSD_pars(3,2)             ! New, @@@ RTS 09/11/12
!   real(fpk) :: n_real(2), n_imag(2)      ! New, @@@ RTS 09/11/12

!  AOP output: Reference values
!    * These are the values at reference wavelength w0
!    * They are set for wavelength w0, then used again

    real(fpk)     :: extinction_ref

!  Help Variables

   character*3  :: cwav
   integer      :: n, k, l, m, istatus, point_index, w, wc, wavmask(maxwav)
   integer      :: n_scatmoms_w, n_aerwavs, local_nwav, wa, wa1, wa2, wastart
   real(fpk)    :: wavelength, Mie_wavelength, Tmat_wavelength, extinction, fa1, fa2, lam, lamstart, lamfinish
   logical      :: trawl

!  Interpolation arrays
!     UV-Vis : 56  is enough wavelengths for 10 nm intervals over a 250-800  nm range
!     SWIr   : 136 is enough wavelengths for 10 nm intervals over a 750-2100 nm range
!    NOTE    : CAN MAKE THESE ARRAYS ALLOCATABLE ----------THINK ABOUT IT !!!!!!!!!

   real(fpk)    :: aerwav(136),local_aodscaling(136),local_aerssalbs(136), local_scatmoms(6,0:maxaermoms,136)

!  Local control

   logical, parameter :: do_iopchecker    = .false.
!   logical, parameter :: do_iopchecker    = .true.
   logical, parameter :: do_aer_Jacobians = .false.

!  Initialize output
!  =================

!  Initialize exception handling

   fail1 = .false.
   fail2 = .false.
   Message_Loading   = ' '
   Messages_Optical  = ' '

!  initialize Aerosol Loading

   Loading        = 0.0d0
   Dloading_Dtau  = 0.0d0     ! Not required
   Dloading_Dpars = 0.0d0
   aerlayerflags = .false.

!  Set local Mie/Tmatrix variables

   do_monodisperse = .false.             ! Always false
   Do_Fmatrix      = .false.             ! Always false
   DO_Expcoeffs    = .false.             ! this will be set later on
   monoradius      = 0.0d0
   do_psd_oldstyle = .false.

!  Initialize optical properties

   extinction_ref    = 0.0d0
   aod_scaling       = 0.0d0
   aerosol_deltau    = 0.0d0
   aerosol_ssalbs    = 0.0d0
   aerosol_scatmoms  = 0.0d0
   aerosol_distchars = 0.0d0
   aertau_unscaled   = 0.0d0

!  Initialize local aerosol properties (Just a precaution)! New, @@@ RTS 09/11/12

!   n_real = 0.0_fpk ; n_imag   = 0.0_fpk
!   PSDIndex = 0    ; PSD_pars = 0.0_fpk

!  Now form the aerosol Loading
!  ----------------------------

!  @@@ Notes: 18 February 2013
!        profiles_lidar routine added (loading case 4)
!         - Read LIDAR Extinction [km-1] and height [km] profiles from FILE
!         - Parcel the entire LIDAR profile into the output array
!         - Ignores z_upperlimit, z_lowerlimit
!         - Only one offline test so far (19 february, 2013)

!    Loading = optical depth profile

!    Derivatives : 
!       Cases 1-3 : dloading_Dtau      = derivative of profile w.r.t the total aerosol optical depth at wavelength w0
!       Case 2    : dloading_Dpars(1)  = derivative of profile w.r.t the relaxation parameter (Exponential)
!       Case 3    : dloading_Dpars(1)  = derivative of profile w.r.t the GDF Peak height
!       Case 3    : dloading_Dpars(2)  = derivative of profile w.r.t the GDF Half Width 
!       Case 4    : dloading_Dpars     = 0 (No Derivatives allowed, LIDAR profile)

!  Case 1: Uniform layer of aerosol
!  ********************************

!   write(*,*)GEMSTOOL_INPUTS%AerLoad%loading_case ; pause 'GRONK'

   if ( GEMSTOOL_INPUTS%AerLoad%loading_case .eq. 1 ) then

      CALL profiles_uniform  &
          ( maxlayers, nlayers, height_grid, do_aer_Jacobians,  & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%loading_upperboundary,      & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%loading_lowerboundary,      & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%aertau_input_w0,            & ! Inputs
            Loading, Dloading_Dtau,                             & ! output
            fail1, message_Loading(1), message_Loading(2) )       ! Exception Handling

      if ( fail1 ) message_Loading(3) = 'Uniform aerosol Loading failed'

!  Case 2: Exponential decay profile
!  *********************************

   else if ( GEMSTOOL_INPUTS%AerLoad%loading_case .eq. 2 ) then

      CALL profiles_expone &
          ( maxlayers, nlayers, height_grid, do_aer_Jacobians,  & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%loading_upperboundary,      & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%loading_lowerboundary,      & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%exploading_relaxation,      & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%aertau_input_w0,            & ! Inputs
            Loading, Dloading_Dtau, Dloading_Dpars(:,1),        & ! output
            fail1, message_Loading(1), message_Loading(2) )       ! Exception Handling

      if ( fail1 ) message_Loading(3) = 'Exponential aerosol Loading failed'

!  Case 3: GDF (quasi-Gaussian) profile
!  ************************************

   else if ( GEMSTOOL_INPUTS%AerLoad%loading_case .eq. 3 ) then

      CALL profiles_gdfone &
          ( maxlayers, nlayers, height_grid, do_aer_Jacobians,  & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%loading_upperboundary,      & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%gdfloading_peakheight,      & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%loading_lowerboundary,      & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%gdfloading_halfwidth,       & ! Inputs
            GEMSTOOL_INPUTS%AerLoad%aertau_input_w0,            & ! Inputs
            Loading, Dloading_Dtau, Dloading_Dpars(:,1), Dloading_Dpars(:,2),     & ! output
            fail1, message_Loading(1), message_Loading(2) )                         ! Exception Handling

      if ( fail1 ) message_Loading(3) = 'GDF aerosol Loading failed'

   endif

!  Return if failure at this stage

   if ( fail1 ) return

!  Assign Unscaled loadings, if successful

   do n = 1, nlayers
      aerlayerflags(n) =  ( Loading(n) .ne. 0.0d0  )
      aertau_unscaled(n) = loading(n)
!     write(*,*), loading(n)
      if ( aerlayerflags(n).and.FDAer.and.FDLay.eq.n ) aertau_unscaled(n) = aertau_unscaled(n) * (1.0d0 + FDeps )
!      write(*,*)n,(height_grid(n-1)+height_grid(n))*0.5d0,aerlayerflags(n),loading(n)
   enddo
!  write(*,*)'TOTAL',sum(loading(1:nlayers)) ,GEMSTOOL_INPUTS%AerLoad%aertau_input_w0
!  pause' aerosol loading'

!  Interpolation setup
!  ===================

   if ( interpolate_aerosols ) then
      trawl = .true. ; wa = 0
      if ( .not. do_wavnums ) then
         lamstart = 200.0d0 ; lam = lamstart        !  Smallest wavelength is 200 nm (UVN application)
         do while (trawl)
            lam = lam + 20.0d0
            if ( lam.ge.wav(1) ) then
               wa = wa + 1 ; aerwav(wa) = lam - 20.0d0
               if ( lam .gt. wav(nwav) ) then
                  wa = wa + 1 ; aerwav(wa) = lam ; trawl = .false.
               endif
            endif
         enddo
          n_aerwavs = wa ; local_nwav = n_aerwavs
      else
         lamfinish = 2100.0d0 ; lam = lamfinish     !  Largest wavelength is 2100 nm (NSW application)
         do while (trawl)
            lam = lam - 20.0d0
            if ( lam.le.1.0d+07/wav(1) ) then
               wa = wa + 1 ; aerwav(wa) = lam + 20.0d0
               if ( lam .lt. 1.0d+07/wav(nwav) ) then
                  wa = wa + 1 ; aerwav(wa) = lam ; trawl = .false.
               endif
            endif
         enddo
          n_aerwavs = wa ; local_nwav = n_aerwavs
      endif
   else
      local_nwav = nwav
   endif


!  Check to see if reference wavelength is one of the set. Initialize Mask.

   point_index = 0
   if ( .not. do_wavnums ) then
      if ( interpolate_aerosols ) then
         do w = 1, n_aerwavs
            wavmask(w) = w ; if ( aerwav(w) .eq. GEMSTOOL_INPUTS%AerLoad%reference_w0 ) point_index = w
         enddo
      else
         do w = 1, nwav
            wavmask(w) = w ; if ( wav(w)    .eq. GEMSTOOL_INPUTS%AerLoad%reference_w0 ) point_index = w
         enddo
      endif
   else
      if ( interpolate_aerosols ) then
         do w = 1, n_aerwavs
            wavmask(w) = w ; if ( aerwav(w) .eq. GEMSTOOL_INPUTS%AerLoad%reference_w0 ) point_index = w
         enddo
      else
         do w = 1, nwav
            wavmask(w) = w
         enddo
      endif
   endif

!   write(*,*)local_nwav, n_aerwavs, lambda_index

!  Mask to use if reference wavelength is one of list of wavelengths. [UVN only]

   if ( point_index .ne. 0 ) then
     wavmask(1) = point_index
     wc = 1
     do w = 1, point_index - 1
       wc = wc + 1 ; wavmask(wc) = w
     enddo
     do w = point_index + 1, local_nwav
       wc = wc + 1 ; wavmask(wc) = w
     enddo
   endif

!  debug
!   do w = 1, local_nwav
!      write(*,*)w,wavmask(w),aerwav(w)
!   enddo
!   pause'interp'

!  Initialize

   n_scatmoms = 50000

!  Continuation for avoiding Mie calculation

   if ( GEMSTOOL_INPUTS%Atmosph%do_Tmat_aerosols ) go to 544

! @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
!      M I E   C a l c u l a t i o n 
! @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

!  Prepare the reference-wavelength Mie Inputs
!  ===========================================

   if ( point_index .eq. 0 ) then

!  Only require extinction coefficient if flagged
!  Set the local Mie program inputs (bulk properties only)

      Do_Expcoeffs     = .FALSE.

!  reference wavelength

      wavelength     = GEMSTOOL_INPUTS%AerLoad%reference_w0
      Mie_wavelength = wavelength/1000.0d0

!  progress

      write(*,*)'Regular Mie Aerosol calculation, reference wavelength = ', wavelength

!  BIMODAL vs. SINGLE CALL

      if ( GEMSTOOL_INPUTS%MieTmat%do_bimodal) then
         call RTSMie_master_bimodal &
            ( Do_Expcoeffs, Do_Fmatrix, do_Monodisperse,                                                         & ! I
              GEMSTOOL_INPUTS%MieTmat%PSDIndex,        GEMSTOOL_INPUTS%MieTmat%PSDpars,   MonoRadius,              & ! I
              GEMSTOOL_INPUTS%MieTmat%R1,              GEMSTOOL_INPUTS%MieTmat%R2, GEMSTOOL_INPUTS%MieTmat%FixR1R2, & ! I
              GEMSTOOL_INPUTS%MieTmat%nblocks,         GEMSTOOL_INPUTS%MieTmat%nweights,                           & ! I
              GEMSTOOL_INPUTS%MieTmat%xparticle_limit, GEMSTOOL_INPUTS%MieTmat%R1R2_cutoff,                        & ! I
              n_Fmatrix_angles, Fmatrix_angles,  Mie_wavelength,                                                 & ! I
              GEMSTOOL_INPUTS%MieTmat%nreal,          GEMSTOOL_INPUTS%MieTmat%nimag,                               & ! I
              GEMSTOOL_INPUTS%MieTmat%bimodal_fraction,                                                           & ! I
              BMie_bulk, BMie_asymm, BMie_ncoeffs,                & ! O
              BMie_expcoeffs, BMie_Fmatrix, BMie_dist,            & ! O
              fail2, istatus, Mie_Bmessages, Mie_trace_3 )          ! O
      else
         BMie_dist(:,2) = 0.0d0
         call RTSMie_main  & !---MIE CALL
              ( Do_Expcoeffs, Do_Fmatrix, do_Monodisperse,                                                                & ! I
                GEMSTOOL_INPUTS%MieTmat%PSDIndex(1),     GEMSTOOL_INPUTS%MieTmat%PSDpars(:,1), MonoRadius,                  & ! I
                GEMSTOOL_INPUTS%MieTmat%R1(1),           GEMSTOOL_INPUTS%MieTmat%R2(1),  GEMSTOOL_INPUTS%MieTmat%FixR1R2(1), & ! I
                GEMSTOOL_INPUTS%MieTmat%nblocks(1),      GEMSTOOL_INPUTS%MieTmat%nweights(1),                               & ! I
                GEMSTOOL_INPUTS%MieTmat%xparticle_limit, GEMSTOOL_INPUTS%MieTmat% R1R2_cutoff(1),                           & ! I
                n_Fmatrix_angles, Fmatrix_angles, Mie_wavelength,                                                         & ! I
                GEMSTOOL_INPUTS%MieTmat%nreal(1),       GEMSTOOL_INPUTS%MieTmat%nimag(1),                                   & ! I
                BMie_bulk, BMie_asymm, BMie_ncoeffs, BMie_expcoeffs, BMie_Fmatrix, BMie_dist(:,1), & ! O
                fail2, istatus, Mie_Bmessages(1), Mie_Bmessages(2), Mie_Bmessages(3) )               ! O
      endif

!  Exception handling on everything

      if ( Fail2 ) then  
         do m = 1, 3   
            Messages_Optical(m) = adjustl(trim(Mie_Bmessages(m)))
         enddo
         Messages_Optical(4) = 'Single Mie Call'
        if ( GEMSTOOL_INPUTS%MieTmat%do_bimodal ) Messages_Optical(4) = adjustl(trim(Mie_trace_3))
         Messages_Optical(5) = 'First call to the Regular Mie program in AEROSOL CREATION, reference wavelength'
         return
      endif

!  Set the reference quantity and set the distribution characteristics

      extinction_ref    = BMie_bulk(1)
      aerosol_distchars = BMie_dist

!      write(*,*)do_Varprops, do_bimodal, Max_Varpts, N_Varpts
!      write(*,*)n_real(1),n_real(2),n_imag(1),n_imag(2)
!      write(*,*)wavelength,PSDIndex, PSD_pars(1,1),PSD_pars(2,1)

!     write(*,*)'Ext Ref 0',extinction_ref; pause

!  End Mie reference-wavelength calculation

   endif

!  Prepare General (all-wavelength, all-wavenumber) Mie inputs
!  ===========================================================

!  wavelength loop. First wavelength will be the reference, if in  list.
!  Wavnumber  loop. 

   do wc = 1, local_nwav

!  Wavelengths [nm]

      w = wavmask(wc)
      if ( interpolate_aerosols ) then
         wavelength = aerwav(w)
      else
        if ( do_wavnums      ) wavelength = 1.0d+07/wav(w)
        if ( .not.do_wavnums ) wavelength = wav(w)
      endif

!  progress

      write(*,*)'Regular Mie Aerosol calculation, doing Point/wavelength # ',wc, wavelength

!  wavelength for the Mie code (micron unit)  

      Mie_wavelength = wavelength/1000.0d0

!  Set the local Mie program inputs (general)

      Do_Expcoeffs     = .TRUE.

!  BIMODAL vs. SINGLE CALL

      if ( GEMSTOOL_INPUTS%MieTmat%do_bimodal) then
         call RTSMie_master_bimodal &
            ( Do_Expcoeffs, Do_Fmatrix, do_Monodisperse,                                                         & ! I
              GEMSTOOL_INPUTS%MieTmat%PSDIndex,        GEMSTOOL_INPUTS%MieTmat%PSDpars,   MonoRadius,              & ! I
              GEMSTOOL_INPUTS%MieTmat%R1,              GEMSTOOL_INPUTS%MieTmat%R2, GEMSTOOL_INPUTS%MieTmat%FixR1R2, & ! I
              GEMSTOOL_INPUTS%MieTmat%nblocks,         GEMSTOOL_INPUTS%MieTmat%nweights,                           & ! I
              GEMSTOOL_INPUTS%MieTmat%xparticle_limit, GEMSTOOL_INPUTS%MieTmat%R1R2_cutoff,                        & ! I
              n_Fmatrix_angles, Fmatrix_angles,  Mie_wavelength,                                                 & ! I
              GEMSTOOL_INPUTS%MieTmat%nreal,          GEMSTOOL_INPUTS%MieTmat%nimag,                               & ! I
              GEMSTOOL_INPUTS%MieTmat%bimodal_fraction,                                                           & ! I
              BMie_bulk, BMie_asymm, BMie_ncoeffs,                & ! O
              BMie_expcoeffs, BMie_Fmatrix, BMie_dist,            & ! O
              fail2, istatus, Mie_Bmessages, Mie_trace_3 )          ! O
      else
         BMie_dist(:,2) = 0.0d0
         call RTSMie_main  & !---MIE CALL
              ( Do_Expcoeffs, Do_Fmatrix, do_Monodisperse,                                                                & ! I
                GEMSTOOL_INPUTS%MieTmat%PSDIndex(1),     GEMSTOOL_INPUTS%MieTmat%PSDpars(:,1), MonoRadius,                  & ! I
                GEMSTOOL_INPUTS%MieTmat%R1(1),           GEMSTOOL_INPUTS%MieTmat%R2(1),  GEMSTOOL_INPUTS%MieTmat%FixR1R2(1), & ! I
                GEMSTOOL_INPUTS%MieTmat%nblocks(1),      GEMSTOOL_INPUTS%MieTmat%nweights(1),                               & ! I
                GEMSTOOL_INPUTS%MieTmat%xparticle_limit, GEMSTOOL_INPUTS%MieTmat% R1R2_cutoff(1),                           & ! I
                n_Fmatrix_angles, Fmatrix_angles, Mie_wavelength,                                                         & ! I
                GEMSTOOL_INPUTS%MieTmat%nreal(1),       GEMSTOOL_INPUTS%MieTmat%nimag(1),                                   & ! I
                BMie_bulk, BMie_asymm, BMie_ncoeffs, BMie_expcoeffs, BMie_Fmatrix, BMie_dist(:,1), & ! O
                fail2, istatus, Mie_Bmessages(1), Mie_Bmessages(2), Mie_Bmessages(3) )               ! O
      endif

!  Exception handling on everything

      if ( Fail2 ) then
         write(cwav,'(I3)')wc
         do m = 1, 3
            Messages_Optical(m) = adjustl(trim(Mie_Bmessages(m)))
         enddo
         Messages_Optical(4) = 'Single Mie Call'
         if ( GEMSTOOL_INPUTS%MieTmat%do_bimodal ) Messages_Optical(4) = adjustl(trim(Mie_trace_3))
         Messages_Optical(5) = 'First call to the Regular Mie program in AEROSOL CREATION, wavelength/wavenumber # '//cwav
         return
      endif
      
!  Set the reference quantities, if reference wavelength is in the list.
!   Values for the first (masked) wavelength

      if ( point_index .ne. 0 .and. wc.eq.1 ) then
         extinction_ref = BMie_bulk(1)
         aerosol_distchars = BMie_dist
      endif

!  For the interpolation case, save output to local arrays

      if ( interpolate_aerosols ) then
         local_aodscaling(w)    = BMie_bulk(1) / extinction_ref
         local_aerssalbs(w)     = BMie_bulk(3)
         l = 0 ; local_scatmoms(1,0,w) = 1.0d0
         do while (local_scatmoms(1,l,w).gt.momsize_cutoff.and.l.lt.maxaermoms )
            l = l + 1 ; local_scatmoms(1,l,w) = Bmie_expcoeffs(1,l)
         enddo
         n_scatmoms_w = l
         do l = 0, n_scatmoms_w
            local_scatmoms(2:nmuller,l,w) = BMie_expcoeffs(2:nmuller,l) 
         enddo
         n_scatmoms = min(n_scatmoms, n_scatmoms_w)
         go to 677   
      endif

!  NOW set the optical property output
!  ===================================

!  Extinction and its scaling factor. All wavelengths.

      extinction = BMie_bulk(1)
      aod_scaling(w) = extinction / extinction_ref

!  Assign SSAs and expansion coefficients, single/bimodal aerosol type

      aerosol_ssalbs(w) = BMie_bulk(3)
      l = 0
      aerosol_scatmoms(1,0,w) = 1.0d0
      do while (aerosol_scatmoms(1,l,w).gt.momsize_cutoff.and.l.lt.maxaermoms )
         l = l + 1
         aerosol_scatmoms(1,l,w) = Bmie_expcoeffs(1,l)
      enddo
      n_scatmoms_w = l
      do l = 0, n_scatmoms_w
         do k = 2, nmuller
            aerosol_scatmoms(k,l,w) = BMie_expcoeffs(k,l) 
         enddo
      enddo

!  Update n_scatmoms

      n_scatmoms = min(n_scatmoms, n_scatmoms_w)

!  Apply scalings to loadings

      do n = 1, nlayers
         aerosol_deltau(n,w) = aertau_unscaled(n) * aod_scaling(w)
      enddo

!  debug aerosol optical properties. VERSION TWO only

      if ( do_iopchecker ) then
         do n = 1, nlayers
           if (aerlayerflags(N).and.n.eq.107 ) then
              write(999,'(i4,1p6e20.10)')n,aerosol_deltau(n,w),aerosol_ssalbs(w)
              do l = 0, n_scatmoms_w
                write(999,'(2i5,1p6e20.10)')n,l,(aerosol_scatmoms(k,l,w),k=1,1)
              enddo
!            else
!              write(999,'(i4,1p6e20.10)')n,aerosol_deltau(n,w)
           endif
         enddo
!           pause'Reg 999'
      endif

!  continuation point for avoiding the exact monochromatic solution

677   continue

!  End wavelength/wavenumber loop

   enddo

!  Monochromatic solution, return

   if ( .not. interpolate_aerosols ) return

!  Interpolation, wavelength regime

   if ( .not. do_wavnums ) then
     wastart = 1
     do w = 1, nwav
       wa = wastart ; trawl = .true.
!       write(*,*)w,wav(w),wa,aerwav(wa),aerwav(wa+1)
       do while (trawl)
         if ( wav(w) .ge. aerwav(wa) .and. wav(w) .le.aerwav(wa+1) ) trawl = .false.
       enddo
       wa1 = wa ; wa2 = wa + 1 ; fa1 = ( aerwav(wa2) - wav(w) ) / ( aerwav(wa2) -  aerwav(wa1) ) ; fa2 = 1.0d0 - fa1
       wastart = wa1
       if ( w.lt.nwav) then
          if(wav(w+1).ge.aerwav(wa+1))wastart = wa2
       endif
       aod_scaling(w) = fa1 * local_aodscaling(wa1) + fa2 * local_aodscaling(wa2)
       do n = 1, nlayers
         aerosol_deltau(n,w) = aertau_unscaled(n) * aod_scaling(w) 
       enddo
       aerosol_ssalbs(w) = fa1 * local_aerssalbs(wa1) + fa2 * local_aerssalbs(wa2)
       do l = 0, n_scatmoms
         do k = 1, nmuller
            aerosol_scatmoms(1:nmuller,l,w) = fa1 * local_scatmoms(1:nmuller,l,wa1) + fa2 * local_scatmoms(1:nmuller,l,wa2)
         enddo
!        if ( w.eq.1.and.l.lt.50)write(*,*)l,aerosol_scatmoms(1:nmuller,l,w) 
       enddo
       aerosol_scatmoms(1,0,w) = 1.0d0
!       write(*,*)w,wav(w),fa1,fa2,aerosol_ssalbs(w),n_scatmoms,sum(aerosol_deltau(1:nlayers,w))
     enddo
   endif

!  Interpolation, wavenumber regime
!   12 August 2013 --> KLUTZY CODE here,,,,,,,,,,Improve it!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   if ( do_wavnums ) then
     wastart = 1
     do w = 1, nwav
       wa = wastart ; trawl = .true. ; lam =  1.0d+07/wav(w)
54     continue
       do while (trawl)
         if ( lam .lt. aerwav(wa) ) then
            if ( lam .ge. aerwav(wa+1) ) then
               trawl = .false.
            else if (lam .lt. aerwav(wa+1) ) then
               wa = wa + 1 ; go to 54
            endif
         endif
       enddo
       wa1 = wa ; wa2 = wa + 1 ; fa1 = ( aerwav(wa2) - lam ) / ( aerwav(wa2) -  aerwav(wa1) ) ; fa2 = 1.0d0 - fa1
       wastart = wa1
       aod_scaling(w) = fa1 * local_aodscaling(wa1) + fa2 * local_aodscaling(wa2)
       do n = 1, nlayers
         aerosol_deltau(n,w) = aertau_unscaled(n) * aod_scaling(w)
       enddo
       aerosol_ssalbs(w) = fa1 * local_aerssalbs(wa1) + fa2 * local_aerssalbs(wa2)
       do l = 0, n_scatmoms
         do k = 1, nmuller
            aerosol_scatmoms(1:nmuller,l,w) = fa1 * local_scatmoms(1:nmuller,l,wa1) + fa2 * local_scatmoms(1:nmuller,l,wa2)
         enddo
!        if ( w.eq.1.and.l.lt.50)write(*,*)l,aerosol_scatmoms(1:nmuller,l,w) 
       enddo
       aerosol_scatmoms(1,0,w) = 1.0d0
!       write(*,*)w,wav(w),fa1,fa2,aerosol_ssalbs(w),n_scatmoms,sum(aerosol_deltau(1:nlayers,w))
     enddo
!    pause'Hello world'
   endif

!  Finish Mie calculation 

   return

!  Continuation point for doing T-matrix calculation

544 continue

! @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
!     T M A T R I X   C a l c u l a t i o n 
! @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

!  Prepare the reference-wavelength Tmatrix Inputs
!  ===============================================

   if ( point_index .eq. 0 ) then

!  Only require extinction coefficient if flagged
!  Set the local Mie program inputs (bulk properties only)

      Do_Expcoeffs     = .FALSE.

!  reference wavelength

      wavelength      = GEMSTOOL_INPUTS%AerLoad%reference_w0
      Tmat_wavelength = wavelength/1000.0d0

!  progress

      write(*,*)'Regular Tmatrix Aerosol calculation, reference wavelength = ', wavelength

!  BIMODAL vs. SINGLE CALL

      if ( GEMSTOOL_INPUTS%MieTmat%do_bimodal) then
         call tmat_master_bimodal &
            ( Do_Expcoeffs, Do_Fmatrix, do_Monodisperse,                                                             & ! I
              GEMSTOOL_INPUTS%MieTmat%Do_EqSaSphere,    Do_psd_OldStyle,                                             & ! I
              GEMSTOOL_INPUTS%MieTmat%PSDIndex,         GEMSTOOL_INPUTS%MieTmat%PSDpars,   MonoRadius,               & ! I
              GEMSTOOL_INPUTS%MieTmat%R1,               GEMSTOOL_INPUTS%MieTmat%R2, GEMSTOOL_INPUTS%MieTmat%FixR1R2, & ! I
              GEMSTOOL_INPUTS%MieTmat%bimodal_fraction,                                                              & ! 
              GEMSTOOL_INPUTS%MieTmat%Tmat_Sphtype,     GEMSTOOL_INPUTS%MieTmat%Tmat_nkmax,                          & ! I
              n_Fmatrix_angles,                         GEMSTOOL_INPUTS%MieTmat%Tmat_ndgs,                           & ! I
              GEMSTOOL_INPUTS%MieTmat%Tmat_eps,         GEMSTOOL_INPUTS%MieTmat%Tmat_accuracy,                       & ! I    
              Tmat_wavelength, GEMSTOOL_INPUTS%MieTmat%nreal, GEMSTOOL_INPUTS%MieTmat%nimag,                         & ! I
              BTmat_bulk, BTmat_asymm, BTmat_ncoeffs,                                 & ! O
              BTmat_expcoeffs, BTmat_Fmatrix, BTmat_dist,                             & ! O
              fail2, istatus, Tmat_message, Tmat_trace, Tmat_trace_2, Tmat_trace_3 )    ! O
      else
         BTmat_dist(:,2) = 0.0d0
         call tmat_master  & 
            ( Do_Expcoeffs, Do_Fmatrix, do_Monodisperse,                                                                   & ! I
              GEMSTOOL_INPUTS%MieTmat%Do_EqSaSphere,    Do_psd_OldStyle,                                                   & ! I
              GEMSTOOL_INPUTS%MieTmat%PSDIndex(1),      GEMSTOOL_INPUTS%MieTmat%PSDpars(:,1),   MonoRadius,                & ! I
              GEMSTOOL_INPUTS%MieTmat%R1(1),            GEMSTOOL_INPUTS%MieTmat%R2(1), GEMSTOOL_INPUTS%MieTmat%FixR1R2(1), & ! I
              GEMSTOOL_INPUTS%MieTmat%Tmat_Sphtype,     GEMSTOOL_INPUTS%MieTmat%Tmat_nkmax(1),                             & ! I
              n_Fmatrix_angles,                         GEMSTOOL_INPUTS%MieTmat%Tmat_ndgs(1),                              & ! I
              GEMSTOOL_INPUTS%MieTmat%Tmat_eps(1),      GEMSTOOL_INPUTS%MieTmat%Tmat_accuracy,                             & ! I  
              Tmat_wavelength, GEMSTOOL_INPUTS%MieTmat%nreal(1), GEMSTOOL_INPUTS%MieTmat%nimag(1),                         & ! I
              BTmat_bulk, BTmat_asymm, BTmat_ncoeffs,                   & ! O
              BTmat_expcoeffs, BTmat_Fmatrix, BTmat_dist(:,1),          & ! O
              fail2, istatus, Tmat_message, Tmat_trace, Tmat_trace_2 )    ! O
      endif

!  Exception handling on everything

      if ( Fail2 ) then  
         Messages_Optical(1) = adjustl(trim(Tmat_message))
         Messages_Optical(2) = adjustl(trim(Tmat_trace))
         Messages_Optical(3) = adjustl(trim(Tmat_trace_2))
         Messages_Optical(4) = 'Single Tmatrix Call'
        if ( GEMSTOOL_INPUTS%MieTmat%do_bimodal ) Messages_Optical(4) = adjustl(trim(Tmat_trace_3))
         Messages_Optical(5) = 'First call to the Regular Tmatrix program in AEROSOL CREATION, reference wavelength'
         return
      endif

!  Set the reference quantity and set the distribution characteristics

      extinction_ref    = BTmat_bulk(1)
      aerosol_distchars = BTmat_dist

!  End Tmatrix reference-wavelength calculation

   endif

!  Prepare General (all-wavelength, all-wavenumber) Tmatrix inputs
!  ===============================================================

!  wavelength loop. First wavelength will be the reference, if in  list.
!  Wavnumber  loop.

   do wc = 1, local_nwav

!  Wavelengths [nm]

      w = wavmask(wc)
      if ( interpolate_aerosols ) then
         wavelength = aerwav(w)
      else
        if ( do_wavnums      ) wavelength = 1.0d+07/wav(w)
        if ( .not.do_wavnums ) wavelength = wav(w)
      endif

!  progress

      write(*,*)'Regular Tmatrix Aerosol calculation, doing Point/wavelength # ',wc, wavelength

!  wavelength for the Tmatrix code (micron unit)  

      Tmat_wavelength = wavelength/1000.0d0

!  Set the local Tmatrix program inputs (general)

      Do_Expcoeffs     = .TRUE.

!  BIMODAL vs. SINGLE CALL

      if ( GEMSTOOL_INPUTS%MieTmat%do_bimodal) then
         call tmat_master_bimodal &
            ( Do_Expcoeffs, Do_Fmatrix, do_Monodisperse,                                                             & ! I
              GEMSTOOL_INPUTS%MieTmat%Do_EqSaSphere,    Do_psd_OldStyle,                                             & ! I
              GEMSTOOL_INPUTS%MieTmat%PSDIndex,         GEMSTOOL_INPUTS%MieTmat%PSDpars,   MonoRadius,               & ! I
              GEMSTOOL_INPUTS%MieTmat%R1,               GEMSTOOL_INPUTS%MieTmat%R2, GEMSTOOL_INPUTS%MieTmat%FixR1R2, & ! I
              GEMSTOOL_INPUTS%MieTmat%bimodal_fraction,                                                              & ! 
              GEMSTOOL_INPUTS%MieTmat%Tmat_Sphtype,     GEMSTOOL_INPUTS%MieTmat%Tmat_nkmax,                          & ! I
              n_Fmatrix_angles,                         GEMSTOOL_INPUTS%MieTmat%Tmat_ndgs,                           & ! I
              GEMSTOOL_INPUTS%MieTmat%Tmat_eps,         GEMSTOOL_INPUTS%MieTmat%Tmat_accuracy,                       & ! I    
              Tmat_wavelength, GEMSTOOL_INPUTS%MieTmat%nreal, GEMSTOOL_INPUTS%MieTmat%nimag,                         & ! I
              BTmat_bulk, BTmat_asymm, BTmat_ncoeffs,                                 & ! O
              BTmat_expcoeffs, BTmat_Fmatrix, BTmat_dist,                             & ! O
              fail2, istatus, Tmat_message, Tmat_trace, Tmat_trace_2, Tmat_trace_3 )    ! O
      else
         BTmat_dist(:,2) = 0.0d0
         call tmat_master  & 
            ( Do_Expcoeffs, Do_Fmatrix, do_Monodisperse,                                                                   & ! I
              GEMSTOOL_INPUTS%MieTmat%Do_EqSaSphere,    Do_psd_OldStyle,                                                   & ! I
              GEMSTOOL_INPUTS%MieTmat%PSDIndex(1),      GEMSTOOL_INPUTS%MieTmat%PSDpars(:,1),   MonoRadius,                & ! I
              GEMSTOOL_INPUTS%MieTmat%R1(1),            GEMSTOOL_INPUTS%MieTmat%R2(1), GEMSTOOL_INPUTS%MieTmat%FixR1R2(1), & ! I
              GEMSTOOL_INPUTS%MieTmat%Tmat_Sphtype,     GEMSTOOL_INPUTS%MieTmat%Tmat_nkmax(1),                             & ! I
              n_Fmatrix_angles,                         GEMSTOOL_INPUTS%MieTmat%Tmat_ndgs(1),                              & ! I
              GEMSTOOL_INPUTS%MieTmat%Tmat_eps(1),     GEMSTOOL_INPUTS%MieTmat%Tmat_accuracy,                              & ! I  
              Tmat_wavelength, GEMSTOOL_INPUTS%MieTmat%nreal(1), GEMSTOOL_INPUTS%MieTmat%nimag(1),                         & ! I
              BTmat_bulk, BTmat_asymm, BTmat_ncoeffs,                   & ! O
              BTmat_expcoeffs, BTmat_Fmatrix, BTmat_dist(:,1),          & ! O
              fail2, istatus, Tmat_message, Tmat_trace, Tmat_trace_2 )    ! O
      endif

!  Exception handling on everything

      if ( Fail2 ) then
         write(cwav,'(I3)')wc
         Messages_Optical(1) = adjustl(trim(Tmat_message))
         Messages_Optical(2) = adjustl(trim(Tmat_trace))
         Messages_Optical(3) = adjustl(trim(Tmat_trace_2))
         Messages_Optical(4) = 'Single Tmatrix Call'
         if ( GEMSTOOL_INPUTS%MieTmat%do_bimodal ) Messages_Optical(4) = adjustl(trim(Tmat_trace_3))
         Messages_Optical(5) = 'First call to the Regular Tmatrix program in AEROSOL CREATION, wavelength/wavenumber # '//cwav
         return
      endif
      
!  Set the reference quantities, if reference wavelength is in the list.
!   Values for the first (masked) wavelength

      if ( point_index .ne. 0 .and. wc.eq.1 ) then
         extinction_ref = BTmat_bulk(1)
         aerosol_distchars = BTmat_dist
      endif

!  For the interpolation case, save output to local arrays

      if ( interpolate_aerosols ) then
         local_aodscaling(w)    = BTmat_bulk(1) / extinction_ref
         local_aerssalbs(w)     = BTmat_bulk(3)
         l = 0 ; local_scatmoms(1,0,w) = 1.0d0
         do while (local_scatmoms(1,l,w).gt.momsize_cutoff.and.l.lt.maxaermoms )
            l = l + 1 ; local_scatmoms(1,l,w) = BTmat_expcoeffs(l+1,1)
         enddo
         n_scatmoms_w = l
         do l = 0, n_scatmoms_w
            local_scatmoms(2:nmuller,l,w) = BTmat_expcoeffs(l+1,2:nmuller) 
         enddo
         n_scatmoms = min(n_scatmoms, n_scatmoms_w)
         go to 678  
      endif

!  NOW set the optical property output
!  ===================================

!  Extinction and its scaling factor. All wavelengths.

      extinction = BTmat_bulk(1)
      aod_scaling(w) = extinction / extinction_ref

!  Assign SSAs and expansion coefficients, single/bimodal aerosol type

      aerosol_ssalbs(w) = BTmat_bulk(3)
      l = 0
      aerosol_scatmoms(1,0,w) = 1.0d0
      do while (aerosol_scatmoms(1,l,w).gt.momsize_cutoff.and.l.lt.maxaermoms )
         l = l + 1
         aerosol_scatmoms(1,l,w) = BTmat_expcoeffs(l+1,1)
      enddo
      n_scatmoms_w = l
      do l = 0, n_scatmoms_w
         do k = 2, nmuller
            aerosol_scatmoms(k,l,w) = BTmat_expcoeffs(l+1,k) 
         enddo
      enddo

!  Update n_scatmoms

      n_scatmoms = min(n_scatmoms, n_scatmoms_w)

!  Apply scalings to loadings

      do n = 1, nlayers
         aerosol_deltau(n,w) = aertau_unscaled(n) * aod_scaling(w)
      enddo

!  debug aerosol optical properties. VERSION TWO only

      if ( do_iopchecker ) then
         do n = 1, nlayers
           if (aerlayerflags(N).and.n.eq.107 ) then
              write(999,'(i4,1p6e20.10)')n,aerosol_deltau(n,w),aerosol_ssalbs(w)
              do l = 0, n_scatmoms_w
                write(999,'(2i5,1p6e20.10)')n,l,(aerosol_scatmoms(k,l,w),k=1,1)
              enddo
!            else
!              write(999,'(i4,1p6e20.10)')n,aerosol_deltau(n,w)
           endif
         enddo
!           pause'Reg 999'
      endif

!  continuation point for avoiding the exact monochromatic solution

678   continue

!  End wavelength/wavenumber loop

   enddo

!  Monochromatic solution, return

   if ( .not. interpolate_aerosols ) return

!  Interpolation, wavelength regime

   if ( .not. do_wavnums ) then
     wastart = 1
     do w = 1, nwav
       wa = wastart ; trawl = .true.
       do while (trawl)
         if ( wav(w) .gt. aerwav(wa) .and. wav(w) .le.aerwav(wa+1) ) trawl = .false.
       enddo
       wa1 = wa ; wa2 = wa + 1 ; fa1 = ( aerwav(wa2) - wav(w) ) / ( aerwav(wa2) -  aerwav(wa1) ) ; fa2 = 1.0d0 - fa1
       wastart = wa1
       aod_scaling(w) = fa1 * local_aodscaling(wa1) + fa2 * local_aodscaling(wa2)
       do n = 1, nlayers
         aerosol_deltau(n,w) = aertau_unscaled(n) * aod_scaling(w) 
       enddo
       aerosol_ssalbs(w) = fa1 * local_aerssalbs(wa1) + fa2 * local_aerssalbs(wa2)
       do l = 0, n_scatmoms
         do k = 1, nmuller
            aerosol_scatmoms(1:nmuller,l,w) = fa1 * local_scatmoms(1:nmuller,l,wa1) + fa2 * local_scatmoms(1:nmuller,l,wa2)
         enddo
!        if ( w.eq.1.and.l.lt.50)write(*,*)l,aerosol_scatmoms(1:nmuller,l,w) 
       enddo
       aerosol_scatmoms(1,0,w) = 1.0d0
!       write(*,*)w,wav(w),fa1,fa2,aerosol_ssalbs(w),n_scatmoms,sum(aerosol_deltau(1:nlayers,w))
     enddo
   endif

!  Interpolation, wavenumber regime
!   12 August 2013 --> KLUTZY CODE here,,,,,,,,,,Improve it!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

   if ( do_wavnums ) then
     wastart = 1
     do w = 1, nwav
       wa = wastart ; trawl = .true. ; lam =  1.0d+07/wav(w)
51     continue
       do while (trawl)
         if ( lam .lt. aerwav(wa) ) then
            if ( lam .ge. aerwav(wa+1) ) then
               trawl = .false.
            else if (lam .lt. aerwav(wa+1) ) then
               wa = wa + 1 ; go to 51
            endif
         endif
       enddo
       wa1 = wa ; wa2 = wa + 1 ; fa1 = ( aerwav(wa2) - lam ) / ( aerwav(wa2) -  aerwav(wa1) ) ; fa2 = 1.0d0 - fa1
       wastart = wa1
       aod_scaling(w) = fa1 * local_aodscaling(wa1) + fa2 * local_aodscaling(wa2)
       do n = 1, nlayers
         aerosol_deltau(n,w) = aertau_unscaled(n) * aod_scaling(w)
       enddo
       aerosol_ssalbs(w) = fa1 * local_aerssalbs(wa1) + fa2 * local_aerssalbs(wa2)
       do l = 0, n_scatmoms
         do k = 1, nmuller
            aerosol_scatmoms(1:nmuller,l,w) = fa1 * local_scatmoms(1:nmuller,l,wa1) + fa2 * local_scatmoms(1:nmuller,l,wa2)
         enddo
!        if ( w.eq.1.and.l.lt.50)write(*,*)l,aerosol_scatmoms(1:nmuller,l,w) 
       enddo
       aerosol_scatmoms(1,0,w) = 1.0d0
!       write(*,*),wav(w),aerosol_ssalbs(w),sum(aerosol_deltau(1:nlayers,w))
     enddo
!    pause'Hello world'
   endif

!  Finish T-matrix calculation 

   return

end subroutine GEMSTOOL_AER_PROPERTIES

!  End module

end Module GEMSTOOL_AerProperties_m
