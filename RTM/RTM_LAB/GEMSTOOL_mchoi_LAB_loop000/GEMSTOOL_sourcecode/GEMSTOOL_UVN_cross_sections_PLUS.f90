module GEMSTOOL_UVN_cross_sections_PLUS_m

!  Original construction for GEMS, 23 July 2013
!  UVN-specific Version for GEMS, 12 August 2013.
!  UVN-specific PLUS code (with P/T derivatives), 20 August 2013. (This module)

!  Older notes
!  -----------

!  Revision. 03 September 2012
!   - GET_O2O2XSEC_1, introduced for O2-O2 absorption (Greenblatt 1990 data)

!  Revision. 18 February 2013
!   - Added several more Cross-sections, from GEOCAPE (SAO) compilation.
!   - separated Cross-section data files in Physics_data

!  Revision, 29 November 2016
!   - Added a new routine to use Chappuis-Wulf data for wavelengths above 660 nm
!   - Filter developed to choose O3 data set.

!  Use modules
!  -----------

!  Use numerical Subroutines

   use GEMSTOOL_numerical_m   , only : spline, splint

!  Hitran modules

   use get_hitran_crs_m
   use get_hitran_crs_plus_m

implicit none

!  Precision

integer, parameter :: fpk = SELECTED_REAL_KIND(15)

!  Only main routine is public

public  :: GEMSTOOL_UVN_CROSS_SECTIONS_PLUS
private :: GET_O3XSEC_3,   &       !               updated 10/11/2013
           GET_NO2XSEC_1,  &       ! New 02/18/13; updated 10/11/2013
           GET_BROXSEC_1,  &       ! New 02/18/13; updated 10/11/2013
           GET_HCHOXSEC_1, &       ! New 02/18/13; updated 10/11/2013
           GET_SO2XSEC_2,  &       ! New 02/18/13; updated 10/11/2013
           GET_O2O2XSEC_2, &       ! New 02/18/13; updated 10/11/2013
           GET_O3XSEC_CWM, &       ! New 11/29/16, alternative Ozone
           RAYLEIGH_FUNCTION, &
           fpk

contains

SUBROUTINE GEMSTOOL_UVN_CROSS_SECTIONS_PLUS  &
          ( MAXLAMBDAS, MAXLAYERS, MAXGASES, CO2_PPMV_MIXRATIO,   & ! INPUT
            NLAYERS, NLAMBDAS, LEVEL_TEMPS, LEVEL_PRESS, LAMBDAS, & ! INPUT
            NGASES, WHICH_GASES, HITRAN_PATH, SAO_XSEC_PATH,      & ! INPUT
            DO_TDERIV, DO_PDERIV,                                 & ! INPUT
            DO_GASES,                                             & ! IN/OUT
            RAYLEIGH_XSEC, RAYLEIGH_DEPOL, GAS_XSECS,             & ! OUTPUT
            O3C1_XSECS, O3C2_XSECS, H2O_XSECS, O2_XSECS,          & ! OUTPUT
            dH2OXSECS_dT, dH2OXSECS_dP, dO2XSECS_dT, dO2XSECS_dP, & ! OUTPUT
            FAIL, MESSAGE )                                         ! OUTPUT

   implicit none

!  Precision

   integer, parameter :: fpk = SELECTED_REAL_KIND(15)
!  Key for Sources

!  [SAO compilation = GEOCAPE data set, prepared by K. Chance for GEOCAPE]

!     for O3   : XSEC_SOURCE --> Unrestricted Daumont/Malicet  (SAO)
!     for O3   : XSEC_SOURCE --> Chappuis-Wulf Modtran         (AER) added 11/29/16
!     for NO2  : XSEC_SOURCE --> SAO Compilation
!     for BRO  : XSEC_SOURCE --> SAO Compilation. BIRA
!     for HCHO : XSEC_SOURCE --> SAO Compilation. Cantrell
!     for SO2  : XSEC_SOURCE --> SAO Compilation. BIRA
!     for O2O2 : XSEC_SOURCE --> SAO Compilation. BIRA

!     for H2O, use Hitran CRS routine (K. Chance)
!     for O2,  use Hitran CRS routine (K. Chance)

!  Input arguments
!  ---------------

!  Dimensioning

      INTEGER     :: MAXLAMBDAS, MAXLAYERS, MAXGASES

!  wavelengths
 
      INTEGER     :: NLAMBDAS
      real(fpk),    dimension ( MAXLAMBDAS ) :: LAMBDAS 

!  CO2 mixing ratio

      real(fpk)    :: CO2_PPMV_MIXRATIO

!  Layer control

      INTEGER     :: NLAYERS

!  Level P and T
      real(fpk),    dimension ( 0:MAXLAYERS ) :: LEVEL_TEMPS 
      real(fpk),    dimension ( 0:MAXLAYERS ) :: LEVEL_PRESS 

!  Gas control

      integer                                  :: NGASES
      character(LEN=4), dimension ( maxgases ) :: WHICH_GASES

!  Hitran and SAO path names

      character*(*), intent(in) :: HITRAN_PATH, SAO_XSEC_PATH

!  Derivatives input

      logical, intent(in) ::do_TDERIV, do_PDERIV

!  Input/Output arguments
!  ----------------------

      logical, dimension ( maxgases )          :: DO_GASES

!  Output arguments
!  ----------------

!  Rayleigh cross-sections and depolarization output

      real(fpk),    dimension ( MAXLAMBDAS ) :: RAYLEIGH_XSEC 
      real(fpk),    dimension ( MAXLAMBDAS ) :: RAYLEIGH_DEPOL

!  Gas cross-sections. ON THE LEVEL

      REAL(fpk),    DIMENSION( MAXLAMBDAS, maxgases ) :: GAS_XSECS  

!  O3 cross-sections temperature-fitting coefficients C1 nad C2

      REAL(fpk),    DIMENSION( MAXLAMBDAS ) :: O3C1_XSECS  
      REAL(fpk),    DIMENSION( MAXLAMBDAS ) :: O3C2_XSECS  

!  H2O and O2

      REAL(fpk),    DIMENSION ( MAXLAMBDAS, 0:maxlayers ) :: H2O_XSECS  
      REAL(fpk),    DIMENSION ( MAXLAMBDAS, 0:maxlayers ) :: O2_XSECS  

      REAL(fpk),    DIMENSION ( MAXLAMBDAS, 0:maxlayers ) :: dH2OXSECS_dP
      REAL(fpk),    DIMENSION ( MAXLAMBDAS, 0:maxlayers ) :: dO2XSECS_dP

      REAL(fpk),    DIMENSION ( MAXLAMBDAS, 0:maxlayers ) :: dH2OXSECS_dT
      REAL(fpk),    DIMENSION ( MAXLAMBDAS, 0:maxlayers ) :: dO2XSECS_dT

!  status

      LOGICAL       ::        FAIL
      CHARACTER*(*) ::        MESSAGE

!  Local variables
!  ---------------

      logical            :: do_HITRAN, Choose_BDM
      integer            :: G, W, NLEVELS 
      CHARACTER(LEN=256) :: FILENAME
      REAL(KIND=FPK)     :: Lowest_CWM, Highest_BDM

!  Hitran inputs (local); dummy output

      CHARACTER (LEN=6)  :: the_molecule
      LOGICAL            :: is_wavenum    ! *** T: wavenumber, F: nm ***
      REAL(KIND=FPK)     :: fwhm          ! *** in cm^-1 or nm ***
      real(KIND=FPK)     :: ATM_PRESS ( MAXLAYERS + 1 )
      INTEGER            :: errstat  ! Error status
      CHARACTER(Len=100) :: message_hitran  ! 
      REAL(KIND=FPK)     :: dummy (MAXLAMBDAS,1:maxlayers+1)  

!  Initialize

   do_Hitran = .false.
   fail = .false. ; message = ' '

!  Gases

   DO G = 1, NGASES

!  O3 (Ozone)
!  ==========

!  formerly just the BDM data set which is only good to 660 nm
!   -- Now filter choice for wavelengths > 660 nm (beyond BDM)
!   -- Coding by Rob, 29 November 2016

      IF ( WHICH_GASES(G) == 'O3  ' ) THEN

!   Filter

         lowest_CWM  = 405.4328
         highest_BDM = 660.1823
         Choose_BDM  = .true.
         if ( LAMBDAS(1) - 0.5d0 .gt. lowest_CWM ) then
            if ( LAMBDAS(NLAMBDAS) + 0.5d0 .gt. highest_BDM ) Choose_BDM = .false.
         endif

!  BDM

         if ( Choose_BDM ) then
            FILENAME =adjustl(trim(SAO_XSEC_PATH))//'o3abs_brion_195_660_vacfinal.dat'
            CALL GET_O3XSEC_3                           &
             ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS, &
              gas_xsecs(:,G), O3C1_XSECS, O3C2_XSECS, FAIL, message )
         endif

!  CWM

         if ( .not.Choose_BDM ) then
            FILENAME =adjustl(trim(SAO_XSEC_PATH))//'o3abs_ChappuisWulf_Modtran.dat'
            CALL GET_O3XSEC_CWM                           &
             ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS, &
              gas_xsecs(:,G), O3C1_XSECS, O3C2_XSECS, FAIL, message )
         endif

!  SO2 (Sulfur Dioxide)
!  ====================

      ELSE IF ( WHICH_GASES(G) == 'SO2 ' ) THEN

!  ... Source unknown BIRA/IASB High Resolution. Bogumil SCIAMACHY ???

         FILENAME = adjustl(trim(SAO_XSEC_PATH))//'SO2_298_BISA.nm'
         CALL GET_SO2XSEC_2                           &
          ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS,  &
            gas_xsecs(:,G), FAIL, message )

!  NO2 (Nitrogen Dioxide)
!  ======================

      ELSE IF ( WHICH_GASES(G) == 'NO2 ' ) THEN

!  ... no2r_97.nm

         FILENAME = adjustl(trim(SAO_XSEC_PATH))//'no2r_97.nm'
         CALL GET_NO2XSEC_1                           &
          ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS,  &
            gas_xsecs(:,G), FAIL, message )

!  BRO (Bromine Monoxide)
!  ======================

      ELSE IF ( WHICH_GASES(G) == 'BRO ' ) THEN

!  ... 228kbro10cm.nm

         FILENAME = adjustl(trim(SAO_XSEC_PATH))//'228kbro10cm.nm'
         CALL GET_BROXSEC_1                           &
          ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS,  &
            gas_xsecs(:,G), FAIL, message )

!  HCHO (Formaldehyde)
!  ===================

      ELSE IF ( WHICH_GASES(G) == 'HCHO' ) THEN

!  ... h2co_cc.300 (Chris Cantrell, SAO)

         FILENAME = adjustl(trim(SAO_XSEC_PATH))//'h2co_cc.300'
         CALL GET_HCHOXSEC_1                          &
          ( FILENAME, MAXLAMBDAS,NLAMBDAS, LAMBDAS,   &
            gas_xsecs(:,G), FAIL, message )

!  O2O2 (Oxygen Dimer)
!  ===================

      ELSE IF ( WHICH_GASES(G) == 'O2O2' ) THEN

!  ... O4_294K_BISA.dat, high resolution

         FILENAME = adjustl(trim(SAO_XSEC_PATH))//'O4_294K_BISA.dat'
         CALL GET_O2O2XSEC_2                          &
          ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS,  &
            gas_xsecs(:,G), FAIL, message )

!  H2O .or. O2(Hitran)

      ELSE IF ( WHICH_GASES(G) == 'H2O ' ) THEN
         do_Hitran = .true.
      ELSE IF ( WHICH_GASES(G) == 'O2  ' ) THEN
         do_Hitran = .true.
      ENDIF

!  Exception handling

      IF ( FAIL ) RETURN

   ENDDO

!  Hitran
!  ------

   if ( do_Hitran ) then

!  set the pressures in bars

      nlevels = nlayers + 1
      atm_press(1:nlevels) = level_press(0:nlayers)  / 1013.25d0

!  Use wavelengths !!!!

      fwhm = 0.0d0 ; is_wavenum = .false.

      do g = 1, ngases

         if ( which_gases(g) .eq. 'H2O ' ) then
            the_molecule = 'H2O   '
            if ( do_TDERIV .or. do_PDERIV ) then
               call get_hitran_crs_plus &
              ( Hitran_path, the_molecule, nlambdas, lambdas(1:nlambdas), is_wavenum,              & ! input
                nlevels, atm_press(1:nlevels), level_temps(0:nlayers), fwhm, do_PDERIV, do_TDERIV, & ! input
                H2O_XSECS    (1:nlambdas,0:nlayers), & ! output
                dH2OXSECS_dT(1:nlambdas,0:nlayers),  & ! Output
                dH2OXSECS_dP(1:nlambdas,0:nlayers),  & ! Output
                errstat, message_hitran )              ! Exception handling
            else
               call get_hitran_crs &
              ( Hitran_path, the_molecule, nlambdas, lambdas(1:nlambdas), is_wavenum,  & ! input
                nlevels, atm_press(1:nlevels), level_temps(0:nlayers), fwhm,           & ! input
                H2O_XSECS(1:nlambdas,0:nlayers), errstat, message_hitran, dummy(1:nlambdas,1:nlevels) )
            endif
         else if ( which_gases(g) .eq. 'O2  ' ) then
            the_molecule = 'O2    '
            if ( do_TDERIV .or. do_PDERIV ) then
               call get_hitran_crs_plus &
              ( Hitran_path, the_molecule, nlambdas, lambdas(1:nlambdas), is_wavenum,              & ! input
                nlevels, atm_press(1:nlevels), level_temps(0:nlayers), fwhm, do_PDERIV, do_TDERIV, & ! input
                O2_XSECS    (1:nlambdas,0:nlayers), & ! output
                dO2XSECS_dT(1:nlambdas,0:nlayers),  & ! Output
                dO2XSECS_dP(1:nlambdas,0:nlayers),  & ! Output
                errstat, message_hitran )             ! Exception handling
            else
               call get_hitran_crs &
              ( Hitran_path, the_molecule, nlambdas, lambdas(1:nlambdas), is_wavenum,  & ! input
                nlevels, atm_press(1:nlevels), level_temps(0:nlayers), fwhm,           & ! input
                O2_XSECS(1:nlambdas,0:nlayers), errstat, message_hitran, dummy(1:nlambdas,1:nlevels) )
            endif
         endif

!  Fatal error --> Exit. Warning error --> write to screen and move on !!!!

         write(*,*)'Done Hitran calculation for gas = '//which_gases(g)
         if (errstat.eq.1 ) then
            fail = .true.
            message = adjustl(trim(message_hitran))
            return
         else if ( errstat.eq.2 ) then
            write(*,*)' * '//adjustl(trim(message_hitran))//', for gas = '//which_gases(g)
!mick fix - added logical statement
            do_gases(g) = .false.
         endif

!  Surface pressure derivative. scale Hitran cross-section derivatives

      if ( do_PDERIV .and. do_gases(g) ) then
         if ( which_gases(g).eq.'O2  ' ) THEN
            do w = 1, nlambdas
                dO2XSECS_dP(w,nlayers) = dO2XSECS_dP(w,nlayers) / 1013.25d0
            enddo
          else if ( which_gases(g).eq.'H2O ' ) THEN
            do w = 1, nlambdas
                dH2OXSECS_dP(w,nlayers) = dH2OXSECS_dP(w,nlayers) / 1013.25d0
            enddo
          endif
      endif


!  End gas loop

      enddo

   endif

!  Get the Rayleigh. Input wavelengths in [nm], NOT ANGSTROMS

   CALL RAYLEIGH_FUNCTION                                &
     ( MAXLAMBDAS, CO2_PPMV_MIXRATIO, NLAMBDAS, LAMBDAS, &
       RAYLEIGH_XSEC, RAYLEIGH_DEPOL )

!  FInish

  RETURN
END SUBROUTINE GEMSTOOL_UVN_CROSS_SECTIONS_PLUS

!!

SUBROUTINE RAYLEIGH_FUNCTION                       &
          ( FORWARD_MAXLAMBDAS, CO2_PPMV_MIXRATIO, &
            FORWARD_NLAMBDAS,   FORWARD_LAMBDAS,   &
            RAYLEIGH_XSEC, RAYLEIGH_DEPOL )

   implicit none

!  Precision

   integer, parameter :: fpk = SELECTED_REAL_KIND(15)

!  Rayleigh cross sections and depolarization ratios
!     Bodhaine et. al. (1999) formulae
!     Module is stand-alone.
!     Wavelengths in nm (formerly Angstroms)

!  Input arguments
!  ---------------

!  wavelength
 
      INTEGER     :: FORWARD_MAXLAMBDAS, FORWARD_NLAMBDAS
      real(fpk),    dimension ( FORWARD_MAXLAMBDAS ) :: FORWARD_LAMBDAS 

!  CO2 mixing ratio

      real(fpk)    :: CO2_PPMV_MIXRATIO

!  Output arguments
!  ----------------

!  cross-sections and depolarization output

      real(fpk),    dimension ( FORWARD_MAXLAMBDAS ) :: RAYLEIGH_XSEC 
      real(fpk),    dimension ( FORWARD_MAXLAMBDAS ) :: RAYLEIGH_DEPOL

!  Local variables
!  ---------------

      INTEGER      :: W
      real(fpk)    :: MASS_DRYAIR
      real(fpk)    :: NMOL, PI, CONS
      real(fpk)    :: MO2,MN2,MARG,MCO2,MAIR
      real(fpk)    :: FO2,FN2,FARG,FCO2,FAIR
      real(fpk)    :: LAMBDA_C,LAMBDA_M,LPM2,LP2
      real(fpk)    :: N300M1,NCO2M1,NCO2
      real(fpk)    :: NCO2SQ, NSQM1,NSQP2,TERM

!  data statements and parameters
!  ------------------------------

      DATA MO2  / 20.946D0 /
      DATA MN2  / 78.084D0 /
      DATA MARG / 0.934D0 /

      real(fpk),    PARAMETER ::        S0_A = 15.0556D0
      real(fpk),    PARAMETER ::        S0_B = 28.9595D0

      real(fpk),    PARAMETER ::        S1_A = 8060.51D0
      real(fpk),    PARAMETER ::        S1_B = 2.48099D+06
      real(fpk),    PARAMETER ::        S1_C = 132.274D0
      real(fpk),    PARAMETER ::        S1_D = 1.74557D+04
      real(fpk),    PARAMETER ::        S1_E = 39.32957D0

      real(fpk),    PARAMETER ::        S2_A = 0.54D0

      real(fpk),    PARAMETER ::        S3_A = 1.034D0
      real(fpk),    PARAMETER ::        S3_B = 3.17D-04
      real(fpk),    PARAMETER ::        S3_C = 1.096D0
      real(fpk),    PARAMETER ::        S3_D = 1.385D-03
      real(fpk),    PARAMETER ::        S3_E = 1.448D-04

!  Start of code
!  -------------

!  constants

      NMOL = 2.546899D19
      PI   = DATAN(1.0D0)*4.0D0
      CONS = 24.0D0 * PI * PI * PI

!  convert co2

      MCO2 = 1.0D-06 * CO2_PPMV_MIXRATIO

!  mass of dry air: Eq.(17) of BWDS

      MASS_DRYAIR = S0_A * MCO2 + S0_B

!  start loop

      DO W = 1, FORWARD_NLAMBDAS

!  wavelength in micrometers

      LAMBDA_M = 1.0D-03 * FORWARD_LAMBDAS(W)
      LAMBDA_C = 1.0D-07 * FORWARD_LAMBDAS(W)
!      LAMBDA_M = 1.0D-04 * FORWARD_LAMBDAS(W)             ! Angstrom input
!      LAMBDA_C = 1.0D-08 * FORWARD_LAMBDAS(W)             ! Angstrom input
      LPM2     = 1.0D0 / LAMBDA_M / LAMBDA_M

!  step 1: Eq.(18) of BWDS

      N300M1 = S1_A + ( S1_B / ( S1_C - LPM2 ) ) + &
                      ( S1_D / ( S1_E - LPM2 ) )
      N300M1 = N300M1 * 1.0D-08

!  step 2: Eq.(19) of BWDS

      NCO2M1 = N300M1 * ( 1.0D0 + S2_A * ( MCO2  - 0.0003D0 ) )
      NCO2   = NCO2M1 + 1
      NCO2SQ = NCO2 * NCO2

!  step 3: Eqs. (5&6) of BWDS (Bates' results)

      FN2  = S3_A + S3_B * LPM2
      FO2  = S3_C + S3_D * LPM2 + S3_E * LPM2 * LPM2

!  step 4: Eq.(23) of BWDS
!     ---> King factor and depolarization ratio

      FARG = 1.0D0
      FCO2 = 1.15D0
      MAIR = MN2 + MO2 + MARG + MCO2
      FAIR = MN2*FN2 + MO2*FO2 + MARG*FARG + MCO2*FCO2
      FAIR = FAIR / MAIR
      RAYLEIGH_DEPOL(W) = 6.0D0*(FAIR-1.0D0)/(3.0D0+7.0D0*FAIR)

!  step 5: Eq.(22) of BWDS
!     ---> Cross section

      LP2  = LAMBDA_C * LAMBDA_C
      NSQM1 = NCO2SQ - 1.0D0
      NSQP2 = NCO2SQ + 2.0D0
      TERM = NSQM1 / LP2 / NMOL / NSQP2
      RAYLEIGH_XSEC(W) =  CONS * TERM * TERM * FAIR

!  end loop

      ENDDO

!  finish
!  ------

      RETURN
END SUBROUTINE RAYLEIGH_FUNCTION 

!

SUBROUTINE GET_O3XSEC_3 ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS, &
                          o3c0_xsecs, o3c1_xsecs, o3c2_xsecs, fail, message )

   implicit none

!  Precision

   integer, parameter :: ccpk = SELECTED_REAL_KIND(15)

!  Dimensioning

      INTEGER       :: MAXLAMBDAS

!  Filename

      character*(*) :: FILENAME

!  wavelengths
 
      INTEGER                                :: NLAMBDAS
      real(ccpk),    dimension ( MAXLAMBDAS ) :: LAMBDAS 

!  Output arguments
!  ----------------

   REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: o3c0_xsecs 
   REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: o3c1_xsecs 
   REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: o3c2_xsecs 

!  Exceptiopn handling

      logical             :: FAIL
      character*(*)       :: MESSAGE

!  Local stuff
!  -----------

   integer, parameter :: maxspline = 30100  ! This covers the range 300-600 nm

   logical       :: reading
   integer       :: nbuff, ndata, n, maxdata
   real(ccpk)     :: lamb1, lamb2, wav, val, c1, c2, conversion, xsec, wav1, wav2
   real(ccpk)     :: x(maxspline), y(maxspline), y2(maxspline)
   real(ccpk)     :: yc1(maxspline), yc2(maxspline)
   character*5    :: c5

!  initialize exception handling

   fail    = .false.
   message = ' '

!  Initialize output

   o3c0_xsecs = 0.0d0;  o3c1_xsecs = 0.0d0;  o3c2_xsecs = 0.0d0

!  Buffer control, initialization

   nbuff = 0
   ndata = 1
   lamb1 = lambdas(1)        - 0.5d0
   lamb2 = lambdas(nlambdas) + 0.5d0
   maxdata    = 46501
   conversion = 1.0d+20

!  Read the data, check that window is covered

   open(1,file=adjustl(trim(filename)),err=90,status='old')

!  .. First line is a dummy
         read(1,*)
!  .. Read second line, set lower limit
         read(1,*)wav, val, c1, c2 ; wav1 = wav
!  .. Read more lines, saving to spline buffer, check it does not get too big!
         reading = .true.
         do while (reading .and. ndata .lt. maxdata )
            ndata = ndata + 1
            read(1,*) wav, val, c1, c2
            if ( wav .ge. lamb1 ) then
               if ( wav .le. lamb2 ) then
                  nbuff = nbuff + 1
                  if (nbuff .le. maxspline) then
                     x(nbuff)   = wav
                     y(nbuff)   = val
                     yc1(nbuff) = c1
                     yc2(nbuff) = c2
                  endif
               else if ( wav .gt. lamb2 ) then
                  reading = .false.
                  wav2 = wav
               endif
            endif
         enddo
         if (ndata .eq. maxdata) wav2 = wav
         close(1)

!  Buffer too small

        if (nbuff .gt. maxspline) then
           write(c5,'(I5)')nbuff-1
           message = 'Error: You need to increase maxspline in GET_O3XSEC_3 to at least '//c5
           fail = .true. ; return
        endif

!  No data found

         if ( nbuff.eq.0) then
            message = 'Error: Wavelength range out of bounds: No data found in GET_O3XSEC_3; REMOVE THIS GAS FROM LIST!'
            fail = .true. ; return
         endif
         
!  debug
!        write(*,*)nbuff, lamb1, lamb2, wav1, wav2
!         do n = 1, nbuff
!            write(99,*)x(n),y(n),yc1(n)
!         enddo
!         pause
         
!  Spline the data

         call spline(maxspline,x,y,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and.lambdas(n).le.wav2 ) then
               call splint(maxspline,x,y,y2,nbuff,lambdas(n),xsec)
               o3c0_xsecs(n) = xsec / conversion
            endif
         enddo

         call spline(maxspline,x,yc1,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and. lambdas(n).le.wav2 ) then
               call splint(maxspline,x,yc1,y2,nbuff,lambdas(n),xsec)
               o3c1_xsecs(n) = xsec / conversion
            endif
         enddo

         call spline(maxspline,x,yc2,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and. lambdas(n).le.wav2) then
               call splint(maxspline,x,yc2,y2,nbuff,lambdas(n),xsec)
               o3c2_xsecs(n) = xsec / conversion
            endif
         enddo

!  normal return

   return

!  error return

90 continue
   fail    = .true.
   message = 'Open failure for Xsec file = '//filename(1:LEN(filename))
   return

!  Finish

  return
END SUBROUTINE GET_O3XSEC_3

!

SUBROUTINE GET_O3XSEC_CWM ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS, &
                          o3c0_xsecs, o3c1_xsecs, o3c2_xsecs, fail, message )

!  Get Cross-sections from the Chappuis-Wulf Data set (MODTRAN)
!    Data extracted from the AER Contiunuum Model by R. Spurr 11/29/16
!    This routine written by R. Spurr 11/29/16

   implicit none

!  Precision

   integer, parameter :: ccpk = SELECTED_REAL_KIND(15)

!  Dimensioning

      INTEGER       :: MAXLAMBDAS

!  Filename

      character*(*) :: FILENAME

!  wavelengths
 
      INTEGER                                :: NLAMBDAS
      real(ccpk),    dimension ( MAXLAMBDAS ) :: LAMBDAS 

!  Output arguments
!  ----------------

   REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: o3c0_xsecs 
   REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: o3c1_xsecs 
   REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: o3c2_xsecs 

!  Exceptiopn handling

      logical             :: FAIL
      character*(*)       :: MESSAGE

!  Local stuff
!  -----------

   integer, parameter :: maxspline = 5000  ! This covers the range

   logical        :: reading
   integer        :: nbuff, ndata, n, maxdata
   real(ccpk)     :: lamb1, lamb2, wav, val, c1, c2, conversion, xsec, wav1, wav2
   real(ccpk)     :: x(maxspline), y(maxspline), y2(maxspline)
   real(ccpk)     :: yc1(maxspline), yc2(maxspline)
   character*5    :: c5

!  initialize exception handling

   fail    = .false.
   message = ' '

!  Initialize output

   o3c0_xsecs = 0.0d0;  o3c1_xsecs = 0.0d0;  o3c2_xsecs = 0.0d0

!  Buffer control, initialization

   nbuff = 0
   ndata = 1
   lamb1 = lambdas(1)        - 0.5d0
   lamb2 = lambdas(nlambdas) + 0.5d0
   maxdata    = 3150
   conversion = 1.0d+20

!  Read the data, check that window is covered

   open(1,file=adjustl(trim(filename)),err=90,status='old')

!  .. First line is a dummy
         read(1,*)
!  .. Read second line, set lower limit
         read(1,*)wav, val, c1, c2 ; wav1 = wav
!  .. Read more lines, saving to spline buffer, check it does not get too big!
         reading = .true.
         do while (reading .and. ndata .lt. maxdata )
            ndata = ndata + 1
            read(1,*) wav, val, c1, c2
            if ( wav .ge. lamb1 ) then
               if ( wav .le. lamb2 ) then
                  nbuff = nbuff + 1
                  if (nbuff .le. maxspline) then
                     x(nbuff)   = wav
                     y(nbuff)   = val
                     yc1(nbuff) = c1
                     yc2(nbuff) = c2
                  endif
               else if ( wav .gt. lamb2 ) then
                  reading = .false.
                  wav2 = wav
               endif
            endif
         enddo
         if (ndata .eq. maxdata) wav2 = wav
         close(1)

!  Buffer too small

        if (nbuff .gt. maxspline) then
           write(c5,'(I5)')nbuff-1
           message = 'Error: You need to increase maxspline in GET_O3XSEC_CWM to at least '//c5
           fail = .true. ; return
        endif

!  No data found

         if ( nbuff.eq.0) then
            message = 'Error: Wavelength range out of bounds: No data found in GET_O3XSEC_CWM; REMOVE THIS GAS FROM LIST!'
            fail = .true. ; return
         endif
         
!  debug
!        write(*,*)nbuff, lamb1, lamb2, wav1, wav2
!         do n = 1, nbuff
!            write(99,*)x(n),y(n),yc1(n)
!         enddo
!         pause
         
!  Spline the data

         call spline(maxspline,x,y,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and.lambdas(n).le.wav2 ) then
               call splint(maxspline,x,y,y2,nbuff,lambdas(n),xsec)
               o3c0_xsecs(n) = xsec / conversion
            endif
         enddo

         call spline(maxspline,x,yc1,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and. lambdas(n).le.wav2 ) then
               call splint(maxspline,x,yc1,y2,nbuff,lambdas(n),xsec)
               o3c1_xsecs(n) = xsec / conversion
            endif
         enddo

         call spline(maxspline,x,yc2,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and. lambdas(n).le.wav2) then
               call splint(maxspline,x,yc2,y2,nbuff,lambdas(n),xsec)
               o3c2_xsecs(n) = xsec / conversion
            endif
         enddo

!  normal return

   return

!  error return

90 continue
   fail    = .true.
   message = 'Open failure for Xsec file = '//filename(1:LEN(filename))
   return

!  Finish

  return
END SUBROUTINE GET_O3XSEC_CWM

!

SUBROUTINE GET_NO2XSEC_1 ( FILENAME, MAXLAMBDAS,NLAMBDAS, LAMBDAS,       &
                           no2_crosssecs, fail, message )

   implicit none

!  Precision

   integer, parameter :: ccpk = SELECTED_REAL_KIND(15)

!  Dimensioning

      INTEGER       :: MAXLAMBDAS

!  Filename

      character*(*) :: FILENAME

!  wavelengths
 
      INTEGER                                :: NLAMBDAS
      real(ccpk),    dimension ( MAXLAMBDAS ) :: LAMBDAS 

       
!  Output arguments
!  ----------------

!  Gas cross-sections

      REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: NO2_CROSSSECS 

!  Exceptiopn handling

   logical             :: FAIL
   character*(*)       :: MESSAGE

!  Local stuff
!  -----------

   integer, parameter :: maxspline = 17360 ! This covers the GEMS range 300-600 nm

   logical        :: reading
   integer        :: nbuff, ndata, n, maxdata
   real(ccpk)     :: lamb1, lamb2, wav, val, conversion, xsec, wav1, wav2
   real(ccpk)     :: x(maxspline), y(maxspline), y2(maxspline)
   character*5    :: c5

!  initialize exception handling

   fail    = .false.
   message = ' '

!  Buffer control, initialization

   nbuff = 0
   ndata = 1
   lamb1 = lambdas(1)        - 0.5d0
   lamb2 = lambdas(nlambdas) + 0.5d0
   maxdata    = 21485
   conversion = 1.0d+20

!  Read the data, check that window is covered

    open(1,file=adjustl(trim(filename)),err=90,status='old')

!  .. Read first line, set lower limit
         read(1,*)wav, val ; wav1 = wav
!  .. Read more lines, saving to spline buffer, check it does not get too big!
         reading = .true.
         do while (reading .and. ndata .lt. maxdata )
            ndata = ndata + 1
            read(1,*) wav, val
            if ( wav .ge. lamb1 ) then
               if ( wav .le. lamb2 ) then
                  nbuff = nbuff + 1
                  if (nbuff .le. maxspline) then
                     x(nbuff)   = wav
                     y(nbuff)   = val * conversion
                  endif
               else if ( wav .gt. lamb2 ) then
                  reading = .false.
                  wav2 = wav
               endif
            endif
         enddo
         if (ndata .eq. maxdata) wav2 = wav
         close(1)

!  Buffer too small

        if (nbuff .gt. maxspline) then
           write(c5,'(I5)')nbuff-1
           message = 'Error: You need to increase maxspline in GET_NO2XSEC_1 to at least '//c5
           fail = .true. ; return
        endif

!  No data found

         if ( nbuff.eq.0) then
            message = 'Error: Wavelength range out of bounds: No data found in GET_NO2XSEC_1; REMOVE THIS GAS FROM LIST!'
            fail = .true. ; return
         endif

!  debug
!        write(*,*)nbuff, lamb1, lamb2, wav1, wav2
!         do n = 1, nbuff
!            write(99,*)x(n),y(n)
!         enddo
!         pause
              
!  Spline the data

         call spline(maxspline,x,y,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and.lambdas(n).le.wav2 ) then
               call splint(maxspline,x,y,y2,nbuff,lambdas(n),xsec)
               if ( xsec.lt.0.0d0 ) xsec = 0.0d0
               no2_crosssecs(n) = xsec / conversion
           endif
         enddo

!  normal return

   return

!  error return

90 continue
   fail    = .true.
   message = 'Open failure for Xsec file = '//filename(1:LEN(filename))
   return

!  Finish

   return
END SUBROUTINE GET_NO2XSEC_1

!

SUBROUTINE GET_HCHOXSEC_1 ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS,       &
                            hcho_crosssecs, fail, message )

   implicit none

!  Precision

   integer, parameter :: ccpk = SELECTED_REAL_KIND(15)

!  Dimensioning

      INTEGER       :: MAXLAMBDAS

!  Filename

      character*(*) :: FILENAME

!  wavelengths
 
      INTEGER                                :: NLAMBDAS
      real(ccpk),    dimension ( MAXLAMBDAS ) :: LAMBDAS 
       
!  Output arguments
!  ----------------

!  Gas cross-sections

      REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: HCHO_CROSSSECS 

!  Exceptiopn handling

   logical             :: FAIL
   character*(*)       :: MESSAGE

!  Local stuff
!  -----------

   integer, parameter :: maxspline = 15020 ! This covers the GEMS range 300-600 nm

   logical       :: reading
   integer       :: nbuff, ndata, n, maxdata
   real(ccpk)     :: lamb1, lamb2, wav, val, conversion, xsec, wav1, wav2
   real(ccpk)     :: x(maxspline), y(maxspline), y2(maxspline)
   character*5    :: c5

!  initialize exception handling

   fail    = .false.
   message = ' '

!  Buffer control, initialization

   nbuff = 0
   ndata = 1
   lamb1 = lambdas(1)        - 0.05d0
   lamb2 = lambdas(nlambdas) + 0.05d0
   maxdata    = 15021
   conversion = 1.0d+20

!  Read the data, check that window is covered

    open(1,file=adjustl(trim(filename)),err=90,status='old')

!  .. Read first line, set lower limit
         read(1,*)wav, val ; wav1 = wav
!  .. Read more lines, saving to spline buffer, check it does not get too big!
         reading = .true.
         do while (reading .and. ndata .lt. maxdata )
            ndata = ndata + 1
            read(1,*) wav, val
            if ( wav .ge. lamb1 ) then
               if ( wav .le. lamb2 ) then
                  nbuff = nbuff + 1
                  if (nbuff .le. maxspline) then
                     x(nbuff)   = wav
                     y(nbuff)   = val * conversion
                  endif
               else if ( wav .gt. lamb2 ) then
                  reading = .false.
                  wav2 = wav
               endif
            endif
         enddo
         if (ndata .eq. maxdata) wav2 = wav
         close(1)

!  Buffer too small

        if (nbuff .gt. maxspline) then
           write(c5,'(I5)')nbuff-1
           message = 'Error: You need to increase maxspline in GET_HCHOXSEC_1 to at least '//c5
           fail = .true. ; return
        endif

!  No data found

         if ( nbuff.eq.0) then
            message = 'Error: Wavelength range out of bounds: No data found in GET_HCHOXSEC_1; REMOVE THIS GAS FROM LIST!'
            fail = .true. ; return
         endif

!  debug
!        write(*,*)nbuff, lamb1, lamb2, wav1, wav2
!         do n = 1, nbuff
!            write(99,*)x(n),y(n)
!         enddo
!         pause
              
!  Spline the data

         call spline(maxspline,x,y,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and.lambdas(n).le.wav2 ) then
               call splint(maxspline,x,y,y2,nbuff,lambdas(n),xsec)
               if ( xsec.lt.0.0d0 ) xsec = 0.0d0
               hcho_crosssecs(n) = xsec / conversion
            endif
         enddo

!  normal return

   return

!  error return

90 continue
   fail    = .true.
   message = 'Open failure for Xsec file = '//filename(1:LEN(filename))
   return

!  Finish

   return
END SUBROUTINE GET_HCHOXSEC_1

!

!

SUBROUTINE GET_SO2XSEC_2 ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS,       &
                           so2_crosssecs, fail, message )

   implicit none

!  Precision

   integer, parameter :: ccpk = SELECTED_REAL_KIND(15)

!  Dimensioning

      INTEGER       :: MAXLAMBDAS

!  Filename

      character*(*) :: FILENAME

!  wavelengths
 
      INTEGER                                :: NLAMBDAS
      real(ccpk),    dimension ( MAXLAMBDAS ) :: LAMBDAS 
       
!  Output arguments
!  ----------------

!  Gas cross-sections

      REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: SO2_CROSSSECS 

!  Exceptiopn handling

   logical             :: FAIL
   character*(*)       :: MESSAGE

!  Local stuff
!  -----------

   integer, parameter :: maxspline = 18700 ! This covers the GEMS range 300-600 nm

   logical       :: reading
   integer       :: nbuff, ndata, n, maxdata
   real(ccpk)     :: lamb1, lamb2, wav, val, conversion, xsec, wav1, wav2
   real(ccpk)     :: x(maxspline), y(maxspline), y2(maxspline)
   character*5    :: c5

!  initialize exception handling

   fail    = .false.
   message = ' '

!  Buffer control, initialization

   nbuff = 0
   ndata = 1
   lamb1 = lambdas(1)        - 0.05d0
   lamb2 = lambdas(nlambdas) + 0.05d0
   maxdata    = 23450
   conversion = 1.0d+20

!  Read the data, check that window is covered

    open(1,file=adjustl(trim(filename)),err=90,status='old')

!  .. Read first line, set lower limit
         read(1,*)wav, val ; wav1 = wav
!  .. Read more lines, saving to spline buffer, check it does not get too big!
         reading = .true.
         do while (reading .and. ndata .lt. maxdata )
            ndata = ndata + 1
            read(1,*) wav, val
            if ( wav .ge. lamb1 ) then
               if ( wav .le. lamb2 ) then
                  nbuff = nbuff + 1
                  if (nbuff .le. maxspline) then
                     x(nbuff)   = wav
                     y(nbuff)   = val * conversion
                  endif
               else if ( wav .gt. lamb2 ) then
                  reading = .false.
                  wav2 = wav
               endif
            endif
         enddo
         if (ndata .eq. maxdata) wav2 = wav
         close(1)

!  Buffer too small

        if (nbuff .gt. maxspline) then
           write(c5,'(I5)')nbuff-1
           message = 'Error: You need to increase maxspline in GET_SO2XSEC_1 to at least '//c5
           fail = .true. ; return
        endif

!  No data found

         if ( nbuff.eq.0) then
            message = 'Error: Wavelength range out of bounds: No data found in GET_SO2XSEC_1; REMOVE THIS GAS FROM LIST!'
            fail = .true. ; return
         endif

!  debug
!        write(*,*)nbuff, lamb1, lamb2, wav1, wav2
!         do n = 1, nbuff
!            write(99,*)x(n),y(n)
!         enddo
!         pause
              
!  Spline the data

         call spline(maxspline,x,y,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and.lambdas(n).le.wav2 ) then
               call splint(maxspline,x,y,y2,nbuff,lambdas(n),xsec)
               if ( xsec.lt.0.0d0 ) xsec = 0.0d0
               so2_crosssecs(n) = xsec / conversion
            endif
         enddo

!  normal return

   return

!  error return

90 continue
   fail    = .true.
   message = 'Open failure for Xsec file = '//filename(1:LEN(filename))
   return

!  Finish

   return
END SUBROUTINE GET_SO2XSEC_2

!

SUBROUTINE GET_BROXSEC_1 ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS,       &
                           bro_crosssecs, fail, message )

   implicit none

!  Precision

   integer, parameter :: ccpk = SELECTED_REAL_KIND(15)

!  Dimensioning

      INTEGER       :: MAXLAMBDAS

!  Filename

      character*(*) :: FILENAME

!  wavelengths
 
      INTEGER                                :: NLAMBDAS
      real(ccpk),    dimension ( MAXLAMBDAS ) :: LAMBDAS 

       
!  Output arguments
!  ----------------

!  Gas cross-sections

      REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: BRO_CROSSSECS 

!  Exceptiopn handling

   logical             :: FAIL
   character*(*)       :: MESSAGE

!  Local stuff
!  -----------

   integer, parameter :: maxspline = 10000
   logical       :: reading
   integer       :: nbuff, ndata, n, maxdata
   real(ccpk)     :: lamb1, lamb2, wav, val, conversion, xsec
   real(ccpk)     :: x(maxspline), y(maxspline), y2(maxspline), wav1, wav2
   character*5    :: c5

!  initialize exception handling

   fail    = .false.
   message = ' '

!  Buffer control, initialization

   nbuff = 0
   ndata = 1
   lamb1 = lambdas(1)        - 0.05d0
   lamb2 = lambdas(nlambdas) + 0.05d0
   maxdata    = 6094
   conversion = 1.0d+20

!  Read the data, check that window is covered

    open(1,file=adjustl(trim(filename)),err=90,status='old')

!  .. Read first line, set lower limit
         read(1,*)wav, val ; wav1 = wav
!  .. Read more lines, saving to spline buffer, check it does not get too big!
         reading = .true.
         do while (reading .and. ndata .lt. maxdata )
            ndata = ndata + 1
            read(1,*) wav, val
            if ( wav .ge. lamb1 ) then
               if ( wav .le. lamb2 ) then
                  nbuff = nbuff + 1
                  if (nbuff .le. maxspline) then
                     x(nbuff)   = wav
                     y(nbuff)   = val * conversion
                  endif
               else if ( wav .gt. lamb2 ) then
                  reading = .false.
                  wav2 = wav
               endif
            endif
         enddo
         if (ndata .eq. maxdata) wav2 = wav
         close(1)

!  Buffer too small

        if (nbuff .gt. maxspline) then
           write(c5,'(I5)')nbuff-1
           message = 'Error: You need to increase maxspline in GET_BROXSEC_1 to at least '//c5
           fail = .true. ; return
        endif

!  No data found

         if ( nbuff.eq.0) then
            message = 'Error: Wavelength range out of bounds: No data found in GET_BROXSEC_1; REMOVE THIS GAS FROM LIST!'
            fail = .true. ; return
         endif

!  debug
!        write(*,*)nbuff, lamb1, lamb2, wav1, wav2
!         do n = 1, nbuff
!            write(99,*)x(n),y(n)
!         enddo
!         pause
              
!  Spline the data

         call spline(maxspline,x,y,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and.lambdas(n).le.wav2 ) then
               call splint(maxspline,x,y,y2,nbuff,lambdas(n),xsec)
               if ( xsec.lt.0.0d0 ) xsec = 0.0d0
               bro_crosssecs(n) = xsec / conversion
            endif
         enddo

!  normal return

   return

!  error return

90 continue
   fail    = .true.
   message = 'Open failure for Xsec file = '//filename(1:LEN(filename))
   return

!  Finish

   return
END SUBROUTINE GET_BROXSEC_1

!

SUBROUTINE GET_O2O2XSEC_2 ( FILENAME, MAXLAMBDAS, NLAMBDAS, LAMBDAS,       &
                            o2o2_crosssecs, fail, message )

!  Rob Fix. 10/27/16. Added small number to cut out dross. 

   implicit none

!  Precision

   integer, parameter :: ccpk = SELECTED_REAL_KIND(15)

!  Dimensioning

      INTEGER       :: MAXLAMBDAS

!  Filename

      character*(*) :: FILENAME

!  wavelengths
 
      INTEGER                                :: NLAMBDAS
      real(ccpk),    dimension ( MAXLAMBDAS ) :: LAMBDAS 
       
!  Output arguments
!  ----------------

!  Gas cross-sections

      REAL(ccpk),    DIMENSION( MAXLAMBDAS ) :: O2O2_CROSSSECS 

!  Exceptiopn handling

   logical             :: FAIL
   character*(*)       :: MESSAGE

!  Local stuff
!  -----------

   integer, parameter :: maxspline = 10485 ! This covers the GEMS range 300-600 nm

   logical        :: reading
   integer        :: nbuff, ndata, n, maxdata
   real(ccpk)     :: lamb1, lamb2, wav, val, conversion, xsec, wav1, wav2
   real(ccpk)     :: x(maxspline), y(maxspline), y2(maxspline)
   character*5    :: c5
   real(ccpk), parameter :: small = 1.0d-10 ! Converted value

!  initialize exception handling

   fail    = .false.
   message = ' '

!  Buffer control, initialization

   nbuff = 0
   ndata = 1
   lamb1 = lambdas(1)        - 0.05d0
   lamb2 = lambdas(nlambdas) + 0.05d0
   maxdata    = 12215
   conversion = 1.0d+40

!  Read the data, check that window is covered

    open(1,file=adjustl(trim(filename)),err=90,status='old')

!  .. Read first line, set lower limit
         read(1,*)wav, val ; wav1 = wav
!  .. Read more lines, saving to spline buffer, check it does not get too big!
         reading = .true.
         do while (reading .and. ndata .lt. maxdata )
            ndata = ndata + 1
            read(1,*) wav, val
            if ( wav .ge. lamb1 ) then
               if ( wav .le. lamb2 ) then
                  nbuff = nbuff + 1
                  if (nbuff .le. maxspline) then
                     x(nbuff)   = wav
                     y(nbuff)   = val * conversion
                  endif
               else if ( wav .gt. lamb2 ) then
                  reading = .false.
                  wav2 = wav
               endif
            endif
         enddo
         if (ndata .eq. maxdata) wav2 = wav
         close(1)

!  Buffer too small

        if (nbuff .gt. maxspline) then
           write(c5,'(I5)')nbuff-1
           message = 'Error: You need to increase maxspline in GET_O2O2XSEC_2 to at least '//c5
           fail = .true. ; return
        endif

!  No data found

         if ( nbuff.eq.0) then
            message = 'Error: Wavelength range out of bounds: No data found in GET_O2O2XSEC_2; REMOVE THIS GAS FROM LIST!'
            fail = .true. ; return
         endif

!  debug
!        write(*,*)nbuff, lamb1, lamb2, wav1, wav2
!         do n = 1, nbuff
!            write(99,*)x(n),y(n)
!         enddo
!         pause
              
!  Spline the data

         call spline(maxspline,x,y,nbuff,0.0d0,0.0d0,y2)
         do n = 1, nlambdas
            if ( lambdas(n).ge.wav1 .and.lambdas(n).le.wav2 ) then
               call splint(maxspline,x,y,y2,nbuff,lambdas(n),xsec)
               if ( xsec.lt.0.0d0 ) xsec = 0.0d0
               if ( xsec.lt.small ) xsec = 0.0d0
               o2o2_crosssecs(n) = xsec / conversion
            endif
         enddo

!  normal return

   return

!  error return

90 continue
   fail    = .true.
   message = 'Open failure for Xsec file = '//filename(1:LEN(filename))
   return

!  Finish

   return
END SUBROUTINE GET_O2O2XSEC_2

!  End module

End module GEMSTOOL_UVN_cross_sections_PLUS_m

