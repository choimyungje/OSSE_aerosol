module tmat_master_m

!  This is the master #1 for Tmatrix code
!    ** RT Solutions, Version 1.0, 21 December 2010
!    ** RT Solutions, Version 1.1, 07 January  2011
!    ** RT Solutions, Version 1.2, 29 March    2011
!    ** RT Solutions, Version 1.3, 24 June     2011 (mono control)

use tmat_parameters, only : fpk => tmat_fpkind, d_one,            &
                 NPL, NPL1, NPNG1, NPNG2, NPN2, NPN1, NPN4, NPN6, MAXNPA

use tmat_functions
use tmat_distributions
use tmat_makers
use tmat_scattering

!  Everything PUBLIC here
!  ----------------------

public

contains

subroutine tmat_master ( Tmat_verbose, &
     Do_Expcoeffs, Do_Fmatrix,                 & ! Gp 1   Inputs (Flags)
     Do_Monodisperse, Do_EqSaSphere,           & ! Gp 1   Inputs (Flags)
     Do_psd_OldStyle, psd_Index, psd_pars,     & ! Gp 1/2 Inputs (PSD)
     MonoRadius, R1, R2, FixR1R2,              & ! Gp 2   Inputs (PSD)
     np, nkmax, npna, ndgs, eps, accuracy,     & ! Gp 3   Inputs (General)
     lambda, n_real, n_imag,                   & ! Gp 4   Inputs (Optical)
     tmat_bulk, tmat_asymm, tmat_ncoeffs,      & ! Outputs (Tmat)
     tmat_expcoeffs, tmat_Fmatrix, Tmat_dist,  & ! Outputs (Tmat and PSD)
     fail, istatus, message, trace, trace_2 )    ! Outputs (status)

!  List of Inputs
!  ==============

!  Flag inputs
!  -----------

!      Do_Expcoeffs      - Boolean flag for computing Expansion Coefficients
!      Do_Fmatrix        - Boolean flag for computing F-matrix at equal-angles

!      Do_Monodisperse   - Boolean flag for Doing a Monodisperse calculation
!                          If set, the PSD stuff will be turned off internally

!      Do_EqSaSphere     - Boolean flag for specifying particle size in terms
!                          of the equal-surface-area-sphere radius

!      Do_psd_OldStyle   - Boolean flag for using original PSD specifications

!  General inputs
!  --------------

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

!      NPNA - number of equidistant scattering angles (from 0      
!             to 180 deg) for which the scattering matrix is           
!             calculated.                                              
            
!      EPS and NP - specify the shape of the particles.                
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

!  optical inputs
!  --------------

!      LAMBDA         - wavelength of light (microns)
!      N_REAL, N_IMAG - real and imaginary parts, refractive index (N-i.GE.0)   

!  PSD inputs
!  ----------

!      psd_Index      - Index for particle size distribution of spheres
!      psd_pars       - Parameters characterizing PSD (up to 3 allowed)

!      Monoradius     - Monodisperse radius size (Microns)

!      R1, R2         - Minimum and Maximum radii (Microns)
!      FixR1R2        - Boolean flag for allowing internal calculation of R1/R2

   implicit none

!  Boolean Input arguments
!  -----------------------

!  Verbose output flag

   logical  , intent(in)  :: Tmat_verbose

!  Flags for Expansion Coefficient and Fmatrix calculations

   logical  , intent(in)  :: Do_Expcoeffs
   logical  , intent(in)  :: Do_Fmatrix

!  Logical flag for Monodisperse calculation

   logical  , intent(in)  :: Do_monodisperse

!  Logical flag for using equal-surface-area sepcification

   logical  , intent(in)  :: Do_EqSaSphere

!  Style flag.
!    * This is checked and re-set (if required) for Monodisperse case

   logical  , intent(inout)  :: Do_psd_OldStyle

!  General Input arguments
!  -----------------------

!  integers (nkmax may be re-set for Monodisperse case)

   integer  , intent(in)     :: np, ndgs, npna
   integer  , intent(inout)  :: nkmax

!  Accuracy and aspect ratio

   real(fpk), intent(in)  :: accuracy, eps

!  Optical: Wavelength, refractive index
!  -------------------------------------

   real(fpk), intent(in)  :: lambda, n_real, n_imag

!  PSD inputs
!  ----------

!  Flag for making an internal Fix of R1 and R2
!    ( Not relevant for the Old distribution

   logical, intent(inout)  :: FixR1R2

!  R1 and R2 (intent(inout))

   real(fpk), intent(inout)  :: R1, R2

!  Monodisperse radius (input)

   real(fpk), intent(in)   :: Monoradius

!  PSD index and parameters

   integer  , intent(in)  :: psd_Index
   real(fpk), intent(in)  :: psd_pars (3)

!  Output arguments
!  ----------------

!  Bulk distribution parameters
!    1 = Extinction coefficient
!    2 = Scattering coefficient
!    3 = Single scattering albedo

   real(fpk), intent(out) :: Tmat_bulk (3)

!  Expansion coefficients and Asymmetry parameter

   integer  , intent(out) :: tmat_ncoeffs
   real(fpk), intent(out) :: Tmat_expcoeffs (NPL1,6)
   real(fpk), intent(out) :: Tmat_asymm

!  F-matrix,  optional output

   real(fpk), intent(out) :: Tmat_Fmatrix (MAXNPA,6)

!  Distribution parameters
!    1 = Normalization
!    2 = Cross-section
!    3 = Volume
!    4 = REFF
!    5 = VEFF

   real(fpk), intent(out) :: Tmat_dist (5)

!  Exception handling

   logical       , intent(out) :: fail
   integer       , intent(out) :: istatus
   character*(*) , intent(out) :: message
   character*(*) , intent(out) :: trace
   character*(*) , intent(out) :: trace_2

!  Local Arrays
!  ------------

!  Constants 

   real(fpk)  :: AN(NPN1),ANN(NPN1,NPN1)

! Various quadratures

   real(fpk)  :: X(NPNG2),W(NPNG2)
   real(fpk)  :: S(NPNG2),SS(NPNG2)

   real(fpk)  :: XG(1000) ,WG(1000)
   real(fpk)  :: XG1(2000),WG1(2000)

!  Bessel Master output

   real(fpk)  :: R(NPNG2),DR(NPNG2)
   real(fpk)  :: DDR(NPNG2),DRR(NPNG2),DRI(NPNG2)

   real(fpk)  :: J_BESS  (NPNG2,NPN1)
   real(fpk)  :: Y_BESS  (NPNG2,NPN1)
   real(fpk)  :: JR_BESS (NPNG2,NPN1)
   real(fpk)  :: JI_BESS (NPNG2,NPN1)
   real(fpk)  :: DJ_BESS (NPNG2,NPN1)
   real(fpk)  :: DY_BESS (NPNG2,NPN1)
   real(fpk)  :: DJR_BESS(NPNG2,NPN1)
   real(fpk)  :: DJI_BESS(NPNG2,NPN1)

!  Miscellaneous output

   REAL(fpk)  :: R11(NPN1,NPN1),R12(NPN1,NPN1)
   REAL(fpk)  :: R21(NPN1,NPN1),R22(NPN1,NPN1)
   REAL(fpk)  :: I11(NPN1,NPN1),I12(NPN1,NPN1)
   REAL(fpk)  :: I21(NPN1,NPN1),I22(NPN1,NPN1)
   REAL(fpk)  :: RG11(NPN1,NPN1),RG12(NPN1,NPN1)
   REAL(fpk)  :: RG21(NPN1,NPN1),RG22(NPN1,NPN1)
   REAL(fpk)  :: IG11(NPN1,NPN1),IG12(NPN1,NPN1)
   REAL(fpk)  :: IG21(NPN1,NPN1),IG22(NPN1,NPN1)

!  Tmatrix input ( Kind = 4 )

!   real(kind=4)  :: TR11(NPN6,NPN4,NPN4),TR12(NPN6,NPN4,NPN4)
!   real(kind=4)  :: TR21(NPN6,NPN4,NPN4),TR22(NPN6,NPN4,NPN4)
!   real(kind=4)  :: TI11(NPN6,NPN4,NPN4),TI12(NPN6,NPN4,NPN4)
!   real(kind=4)  :: TI21(NPN6,NPN4,NPN4),TI22(NPN6,NPN4,NPN4)

   real(fpk)  :: TR11(NPN6,NPN4,NPN4),TR12(NPN6,NPN4,NPN4)
   real(fpk)  :: TR21(NPN6,NPN4,NPN4),TR22(NPN6,NPN4,NPN4)
   real(fpk)  :: TI11(NPN6,NPN4,NPN4),TI12(NPN6,NPN4,NPN4)
   real(fpk)  :: TI21(NPN6,NPN4,NPN4),TI22(NPN6,NPN4,NPN4)

!  Coefficients

   REAL(fpk)  :: ALPH1(NPL),ALPH2(NPL),ALPH3(NPL)
   REAL(fpk)  :: ALPH4(NPL),BET1(NPL), BET2(NPL)
   REAL(fpk)  :: AL1(NPL),AL2(NPL),AL3(NPL)
   REAL(fpk)  :: AL4(NPL),BE1(NPL),BE2(NPL)

!  T-matrix results

   real(fpk)  :: TR1(NPN2,NPN2),TI1(NPN2,NPN2)

!  Local variables
!  ---------------

!  Debug flag and unit

   logical    :: do_debug_output
   integer    :: debug_unit, du

!  PSD functions

   REAL(fpk)  :: PSDF(2000)

!  Local integers, etc.

   integer       :: LMAX, L1MAX, L1M, L1
   integer       :: I, NK, INK, NCHECK, IXXX, II, INM1, M1, M
   integer       :: N, N1, N2, NN1, NN2, N11, N22, NM1, NNM, NM
   integer       :: NMA, NMAX, NMAX1, NMIN, MMAX
   integer       :: NGAUSS, NNNGGG, NGAUS, NGGG
   logical       :: first_loop, second_loop, third_loop
   logical       :: fail_1, fail_2, faildist
   character*90  :: message_1, message_2
   character*4   :: c4
   character*1   :: c1

!  Local FP Variables

   real(fpk)  :: Greek_pie, DDELT, RAT, Z1, Z2, Z3, WALB
   real(fpk)  :: PI, PPI, PIR, PII, radius, XEV, REFF, VEFF
   real(fpk)  :: NDENS, GXSEC, VOLUME
   real(fpk)  :: CSCAT, CEXT, COEFF1, CSCA, CEXTIN
   real(fpk)  :: DQSCA, DEXT, DSCA, WGSC, WGXT
   real(fpk)  :: QXT, QSC, QSCA1, QEXT1, QSCA, QEXT, DQEXT
   real(fpk)  :: TR1NN, TI1NN, TR1NN1, TI1NN1, DN1, WGII
   real(fpk)  :: ZZ1, ZZ2, ZZ3, ZZ4, ZZ5, ZZ6, ZZ7, ZZ8

!  Report PSD calculation progress. Now linked to Tmat_Verbose flag

   logical    :: report_progress
   !logical    :: report_progress=.true.

!  Start Code
!  ----------

!  Report progress flag

   report_progress = Tmat_verbose

!  debug output flag

!   do_debug_output = .true.  ; du = 23
   do_debug_output = .false. ; du = 23
   debug_unit      = 23 ; du = debug_unit
   if ( do_debug_output ) then
      open(du,file='Debug_tmat_output.log', status = 'unknown' )
   endif

!  Initialize exception handling

   fail    = .false.
   istatus = 0
   message = ' '
   trace   = ' '
   trace_2 = ' '

!  Pie

   Greek_pie = dacos(-d_one)

!  Debug input check

!   write(*,*)                                  &
!     Do_Expcoeffs, Do_Fmatrix,                 & ! Gp 1 Inputs (Flags)
!     Do_EqSaSphere, Do_psd_OldStyle,           & ! Gp 1 Inputs (Flags)
!     psd_Index,  psd_pars, R1, R2, FixR1R2,    & ! Gp 2 Inputs (PSD)
!     np, nkmax, npna, ndgs, eps, accuracy,     & ! Gp 3 Inputs (General)
!     lambda, n_real, n_imag                      ! Gp 4 Inputs (Optical)

!  Initialize Basic output

   tmat_dist = 0.0d0
   tmat_bulk = 0.0d0

!  Initialize Coefficient output

   if ( Do_Expcoeffs ) then
      tmat_ncoeffs   = 0
      tmat_expcoeffs = 0.0d0
      tmat_asymm     = 0.0d0
   endif

!  Initialize F-matrix

   if ( Do_Expcoeffs.and. Do_Fmatrix ) then
      tmat_Fmatrix      = 0.0d0
   endif

!  Check integer
!    NCHECK = 1, Except for Chebyshev Odd-power and spherical

   NCHECK=0
   IF (NP.EQ.-1.OR.NP.EQ.-2)      NCHECK=1   !  Spheroids, Cylinders
   IF (NP.GT.0.AND.(-1)**NP.EQ.1) NCHECK=1   !  Even-powered Chebyshevs

!  Equivalent sphere Radius factor
!    = 1, for Volume, 3 choices for

   if ( Do_EqSaSphere ) then
      if ( NP.EQ.-1 ) then
         call Eqv_radius_spheroids ( eps, rat )
      else if ( NP.EQ.-2 ) then
         call Eqv_radius_cylinder ( eps, rat )
      else if ( NP.GT.0) then
         call Eqv_radius_chebyshev ( np, eps, rat )
      else
         RAT = 1.0d0
      endif
   else
      RAT = 1.0d0
   endif

!  debug output

   if ( do_debug_output ) then
      write(du,8000)RAT 
      IF(NP.EQ.-1.AND.EPS.GE.1D0) write(du,7000)EPS
      IF(NP.EQ.-1.AND.EPS.LT.1D0) write(du,7001)EPS
      IF(NP.GE.0) write(du,7100)NP,EPS
      IF(NP.EQ.-2.AND.EPS.GE.1D0) write(du,7150)EPS
      IF(NP.EQ.-2.AND.EPS.LT.1D0) write(du,7151)EPS
      write(du,7400) LAMBDA,N_REAL,N_IMAG
      write(du,7200) ACCURACY
 8000 FORMAT ('RAT=',F8.6)
 7000 FORMAT('RANDOMLY ORIENTED OBLATE SPHEROIDS, A/B=',F11.7)
 7001 FORMAT('RANDOMLY ORIENTED PROLATE SPHEROIDS, A/B=',F11.7)
 7100 FORMAT('RANDOMLY ORIENTED CHEBYSHEV PARTICLES, T',I1,'(',F5.2,')')
 7150 FORMAT('RANDOMLY ORIENTED OBLATE CYLINDERS, D/L=',F11.7)
 7151 FORMAT('RANDOMLY ORIENTED PROLATE CYLINDERS, D/L=',F11.7)
 7200 FORMAT ('ACCURACY OF COMPUTATIONS DDELT = ',D8.2)
 7400 FORMAT('LAMBDA=',F10.6,3X,'N_REAL=',D10.4,3X,'N_IMAG=',D10.4)
   endif

!  Accuracy (Why 0.1d0 ???)

   DDELT = 0.1D0*ACCURACY
!   DDELT = ACCURACY

!  Various quantities

   PI  = 2.0d0 * Greek_pie / lambda
   PPI = PI * PI
   PIR = PPI * n_real
   PII = PPI * n_imag

!  Monodisperse
!  ------------

!    Multiply RAT bymonodisperse radius.
!    Set trivial quadratures

   if ( Do_monodisperse ) then
      Do_psd_Oldstyle = .false.
      RAT = RAT * Monoradius
      NKMAX = -1 ; NK = 1
      XG1(1) = 1.0d0 ; WG1(1) = 1.0d0
   endif

!  Skip PSD stuff if Monodisperse

   if ( Do_monodisperse ) GO TO 77

!  Particle Radii and PSD values
!  -----------------------------

!  Number of distribution points

   NK = NKMAX + 2

!  Power law, Fix the R1 and R2

   IF ( Do_psd_Oldstyle ) then
      IF (psd_Index.EQ.3 .and.FixR1R2 ) then
         CALL POWER (psd_pars(1),psd_pars(2),R1,R2)
      ENDIF
   ENDIF

!  Distribution quadratures

!   CALL GAULEG_wrong(-d_one,d_one,XG,WG,NK)
   CALL GAULEG_right(NK,0,0,XG,WG)

!  Normalize Quadratures to the given range [R1,R2]

   Z1=(R2-R1)*0.5D0
   Z2=(R1+R2)*0.5D0
   Z3=R1*0.5D0

!  Old Style, For modified Power Law (NDISTR = 5 ) double the number of Quadratures

   IF ( Do_psd_Oldstyle ) then
      IF (psd_Index.EQ.5) THEN
         DO I=1,NK
            XG1(I)=Z3*XG(I)+Z3
            WG1(I)=WG(I)*Z3
         ENDDO
         DO I=NK+1,2*NK
            II=I-NK
            XG1(I)=Z1*XG(II)+Z2
            WG1(I)=WG(II)*Z1
         ENDDO
         NK=NK*2
      ELSE
         DO I=1,NK
            XG1(I)=Z1*XG(I)+Z2
            WG1(I)=WG(I)*Z1
         ENDDO
      ENDIF
   ENDIF

!  New Style, Set physical quantities

   IF ( .not. Do_psd_Oldstyle ) then
      DO I=1,NK
         XG1(I)=Z1*XG(I)+Z2
         WG1(I)=WG(I)*Z1
      ENDDO
   ENDIF

! Debug
!   do i=1,nk
!      write(*,*)xg(i),wg(i), XG1(I), WG1(I)
!   enddo
!   pause

!  Distribution values. Old Scheme
!  ===============================

   IF ( Do_psd_OldStyle ) then

!  Psd old-style

      CALL DISTRB                                  &
       ( NK, XG1, psd_Index, R1, DO_DEBUG_OUTPUT,  & ! Inputs
         psd_pars(1), psd_pars(2), psd_pars(3),    & ! Inputs
         WG1, NDENS, GXSEC, VOLUME, REFF, VEFF)      ! Outputs

!  Distribution outputs

      tmat_dist(1) = NDENS
      tmat_dist(2) = GXSEC
      tmat_dist(3) = VOLUME
      tmat_dist(4) = REFF
      tmat_dist(5) = VEFF

   ENDIF

!  Distribution values, New scheme
!  ===============================

!    2000 is the dimension given for XG1 and WG1

   IF ( .not. Do_psd_OldStyle ) then

!  Get the PSD

      CALL DISTRB_new                         & 
       ( 2000, psd_Index, psd_pars, XG1, NK, & ! Inputs
         PSDF, message, faildist )             ! Outputs

!  Exception handling

      if ( faildist ) then
         write(c1,'(i1)')psd_index
         trace   = 'call from DISTRB_new, PSD type '//c1
         trace_2 = 'tmat_matrix_PLUS module; distribution failure'
         fail = .true. ; istatus = 2 ; return
      endif

!  Bulk properties

      call DISTRB_bulk        &
       ( 2000, XG1, NK, PSDF, & ! Inputs
         WG1, tmat_dist )       ! Outputs

!  debug
!   do i = 1, nk
!      write(*,*) XG1(I), WG1(i)
!   enddo

!  Finish New distribution clause

   endif

!  debug. FD testing successful for Log-normal, 6 January 2011
!   write(*,*)tmat_dist(1)
!   write(*,*)tmat_dist(2)
!   write(*,*)tmat_dist(3)
!   write(*,*)tmat_dist(4)
!   write(*,*)tmat_dist(5)
!   pause'hello'

!  Debug (adapted from the original)

   if ( do_debug_output ) then
      write(du,8002)R1,R2
 8002 FORMAT('R1=',F10.6,'   R2=',F10.6)
      IF (DABS(RAT-1D0).LE.1D-6) write(du,8003) tmat_dist(4) ,tmat_dist(5) 
      IF (DABS(RAT-1D0).GT.1D-6) write(du,8004) tmat_dist(4) ,tmat_dist(5) 
 8003 FORMAT('EQUAL-VOLUME-SPHERE REFF=',F8.4,'   VEFF=',F7.4)
 8004 FORMAT('EQUAL-SURFACE-AREA-SPHERE REFF=',F8.4, '   VEFF=',F7.4)
      write(du,7250)NK
 7250 FORMAT('NUMBER OF GAUSSIAN QUADRATURE POINTS ', 'IN SIZE AVERAGING =',I4)
   endif

!  ***********************
!       Main section
!  ***********************

!  Continuation point for Avoiding PSD

77 continue

!  Initialize
!  ----------

!  Initialize Bulk quantities

   CSCAT  = 0D0
   CEXTIN = 0D0

!  Initialize Expansion Coefficients

   L1MAX  = 0
   if ( Do_Expcoeffs ) then
      DO I=1,NPL
         ALPH1(I)=0D0
         ALPH2(I)=0D0
         ALPH3(I)=0D0
         ALPH4(I)=0D0
         BET1(I)=0D0
         BET2(I)=0D0
      ENDDO      
   endif

!  tempo check
!   do ink = 1, nk
!      write(*,*)ink,rat*xg1(nk-ink+1)
!   enddo
!   pause'radii'

!  Start distribution point loop
!  -----------------------------

!   DO 56 INK=1,1          ! debug only

   DO 56 INK=1,NK
      I=NK-INK+1

!  Radius

      radius = RAT*XG1(I)
      XEV  = 2D0 * Greek_pie * radius / lambda

!  Check maximum particle size

      IXXX = XEV+4.05D0*XEV**0.333333D0
      INM1 = MAX0(4,IXXX)

      IF (INM1.GE.NPN1) then
         istatus = 2
         write(c4,'(I4)')inm1+2
         message ='INM1 >/= NPN1. Execution Terminated. Action: increase NPN1 to at least '//c4
         trace   = 'check maximum particle size'
         trace_2 = 'tmat_master module; start of Point loop'
         fail = .true. ;return
      endif

!  initialize coefficients

      QEXT1=0D0
      QSCA1=0D0

!  Round ONE
!  =========

!  First Coefficient loop

      NMA = INM1 - 1
      FIRST_LOOP = .true.

      DO while ( first_loop .and. nma .lt. NPN1 )


         NMA = NMA + 1
         NMAX=NMA
         MMAX=1
         NGAUSS=NMAX*NDGS

!  Check NGAUSS value

         IF (NGAUSS.GE.NPNG1) then
            istatus = 2
            write(c4,'(I4)')NGAUSS+1
            message ='NGAUSS >/= NPNG1. Execution Terminated. Action: increase NPNG1 to at least '//c4
            trace   = 'NGAUSS value too big: just before call to tmatrix_constants'
            trace_2 = 'tmat_master module'
            fail = .true. ;return
         endif

!  Set up constants

         call tmatrix_constants            &
         ( ngauss, nmax, np, eps,          & ! inputs
           x, w, an, ann, s, ss )            ! outputs

!               if ( nma .eq. 20 ) then
!                write(*,*)nma,Radius
!               do n = 1, ngauss*2
!                  write(50,*)n,s(n),ss(n)
!               enddo
!               endif
!               pause'2'

!  Set up Bessel functions

         call tmatrix_vary                       &
     ( n_real, n_imag, radius, PI, x,            & ! inputs
       eps, np, ngauss, nmax,                    & ! inputs
       R, DR, DDR, DRR, DRI,                     & ! outputs
       j_bess,  y_bess,  jr_bess,  ji_bess,      & ! Outputs
       dj_bess, dy_bess, djr_bess, dji_bess )      ! Outputs

!  Debug
!     write(0,*)'First loop test',nmax,2*ngauss
!      do i = 1, 2*ngauss
!        write(76,116)i,ddr(i),drr(i),dri(i)
!        do n = 1, nmax
!           write(76,117)i,n,j_bess(i,n),jr_bess(i,n),ji_bess(i,n),y_bess(i,n)
!           write(76,117)i,n,dj_bess(i,n),djr_bess(i,n),dji_bess(i,n),dy_bess(i,n)
!         enddo
!      enddo
!      pause'First loop test, Write fort 76'
!116   format(i5 ,1p3e20.10)
!117   format(2i5,1p4e20.10)

!  First Call to TMATRIX-R0

         call tmatrix_R0                           &
     ( NGAUSS, NMAX, NCHECK, X, W, AN, ANN,        & ! Inputs
       PPI, PIR, PII, R, DR, DDR, DRR, DRI,        & ! Inputs
        j_bess,  y_bess,  jr_bess,  ji_bess,       & ! Inputs
       dj_bess, dy_bess, djr_bess, dji_bess,       & ! Inputs
       R12, R21, I12, I21, RG12, RG21, IG12, IG21, & ! Outputs
       TR1, TI1, fail, message, trace )              ! Outputs

!      do iiii = 1, 2*nmax
!      do jjjj = 1, 2*nmax
!          write(58,'(2i5,1p2e16.7)')Iiii,Jjjj,TR1(Iiii,Jjjj),TI1(Iiii,Jjjj)
!      enddo
!      enddo
!      pause'58'

!       write(0,*)nma,first_loop
!            pause'First trio'

!  Exception handling

         if ( fail ) then
            write(c4,'(i4)')nma
            trace_2 = 'tmat_master module: First Call to Tmatrix_r0, NMA = '//c4
            return
         endif

!  Local computations, and absolute differences

         QEXT=0D0
         QSCA=0D0
         DO N=1,NMAX
            N1=N+NMAX
            TR1NN=TR1(N,N)
            TI1NN=TI1(N,N)
            TR1NN1=TR1(N1,N1)
            TI1NN1=TI1(N1,N1)
            !DN1=DFLOAT(2*N+1)
            DN1=REAL(2*N+1,fpk)
            QSCA=QSCA+DN1*(TR1NN*TR1NN+TI1NN*TI1NN +TR1NN1*TR1NN1+TI1NN1*TI1NN1)
            QEXT=QEXT+(TR1NN+TR1NN1)*DN1
         ENDDO
         DSCA=DABS((QSCA1-QSCA)/QSCA)
         DEXT=DABS((QEXT1-QEXT)/QEXT)

!  Local value

         QEXT1=QEXT
         QSCA1=QSCA

!  Second loop convergence

         NMIN=DBLE(NMAX)/2D0+1D0
         second_loop = .true.
         N = Nmin - 1

!               write(*,*)qext,nmin,nmax

         DO while ( second_loop .and. N.lt.nmax )
            N = N + 1
            N1=N+NMAX
            TR1NN=TR1(N,N)
            TI1NN=TI1(N,N)
            TR1NN1=TR1(N1,N1)
            TI1NN1=TI1(N1,N1)
            !DN1=DFLOAT(2*N+1)
            DN1=REAL(2*N+1,fpk)
            DQSCA=DN1*(TR1NN*TR1NN+TI1NN*TI1NN+TR1NN1*TR1NN1+TI1NN1*TI1NN1)
            DQEXT=(TR1NN+TR1NN1)*DN1
            DQSCA=DABS(DQSCA/QSCA)
            DQEXT=DABS(DQEXT/QEXT)
            NMAX1=N
            IF (DQSCA.LE.DDELT.AND.DQEXT.LE.DDELT) second_loop = .false.
         ENDDO

!         write(*,*)'After 12',NMA,DQSCA,DQEXT
!         pause

!  Exception handling

         IF (NMA.EQ.NPN1) THEN
            fail = .true.
            message ='NMA = NPN1. No convergence, Execution Terminated'
            trace   = 'First use of Tmatrix for DQSCA and DQEXT' 
            trace_2 = 'tmat_master module'
            istatus = 2
            return
         endif

!  First loop covergence

         IF(DSCA.LE.DDELT.AND.DEXT.LE.DDELT) first_loop = .false.

      ENDDO

!   after 55 pause
!            pause'after 55'

!  Warning flag

      IF (NGAUSS.EQ.NPNG1) THEN
         message = 'WARNING: NGAUSS=NPNG1'
         trace   = 'After First use of Tmatrix for DQSCA and DQEXT' 
         trace_2 = 'tmat_master module'
         istatus = 1
      endif

!  Round Two
!  =========

!  third Coefficient loop

      NNNGGG=NGAUSS+1
      NGAUS = NNNGGG - 1
      THIRD_LOOP = .true.
      MMAX=NMAX1

      DO while ( third_loop .and. NGAUS .lt. NPNG1 )

         NGAUS = NGAUS + 1
         NGAUSS=NGAUS
         NGGG=2*NGAUSS

!  Set up constants

         call tmatrix_constants            &
         ( ngauss, nmax, np, eps,          & ! inputs
           x, w, an, ann, s, ss )            ! outputs

!  Set up Bessel functions

         call tmatrix_vary                       &
     ( n_real, n_imag, radius, PI, x,            & ! inputs
       eps, np, ngauss, nmax,                    & ! inputs
       R, DR, DDR, DRR, DRI,                     & ! outputs
       j_bess,  y_bess,  jr_bess,  ji_bess,      & ! Outputs
       dj_bess, dy_bess, djr_bess, dji_bess )      ! Outputs

!  Second Call to TMATRIX-R0

         call tmatrix_R0                           &
     ( NGAUSS, NMAX, NCHECK, X, W, AN, ANN,        & ! Inputs
       PPI, PIR, PII, R, DR, DDR, DRR, DRI,        & ! Inputs
        j_bess,  y_bess,  jr_bess,  ji_bess,       & ! Inputs
       dj_bess, dy_bess, djr_bess, dji_bess,       & ! Inputs
       R12, R21, I12, I21, RG12, RG21, IG12, IG21, & ! Outputs
       TR1, TI1, fail, message, trace )              ! Outputs

!  Exception handling

         if ( fail ) then
            write(c4,'(i4)')nma
            trace_2 = 'tmat_master module: Second Call to Tmatrix_r0, NMA = '//c4
            istatus = 2
            return
         endif

!  calculate again

         QEXT=0D0
         QSCA=0D0
         DO 104 N=1,NMAX
            N1=N+NMAX
            TR1NN=TR1(N,N)
            TI1NN=TI1(N,N)
            TR1NN1=TR1(N1,N1)
            TI1NN1=TI1(N1,N1)
            !DN1=DFLOAT(2*N+1)
            DN1=REAL(2*N+1,fpk)
            QSCA=QSCA+DN1*(TR1NN*TR1NN+TI1NN*TI1NN+TR1NN1*TR1NN1+TI1NN1*TI1NN1)
            QEXT=QEXT+(TR1NN+TR1NN1)*DN1
  104    CONTINUE

!  Difference and upgrade

         DSCA=DABS((QSCA1-QSCA)/QSCA)
         DEXT=DABS((QEXT1-QEXT)/QEXT)
         QEXT1=QEXT
         QSCA1=QSCA

!  Convergence on third loop

         IF(DSCA.LE.DDELT.AND.DEXT.LE.DDELT) third_loop = .false.

!  Warning flag
  
         IF (NGAUS.EQ.NPNG1) THEN
            message = 'WARNING: NGAUS=NPNG1'
            trace   = 'Occuring at the end of third Tmatrix loop'
            trace_2 = 'tmat_master module'
            istatus = 1
         endif

!  End 3rd loop

      enddo

!  Exception handling

      IF (NMAX1.GT.NPN4) THEN
         write(c4,'(i4)')nmax1+1
         message ='NMAX1 > NPN4. No convergence, execution terminated. Action: increase NPN4 to at least '//c4
         trace = 'After second application of TMAT'
         trace_2 = 'tmat_master module'
         fail = .true.
         istatus = 2
         return
      endif

!  Again for Qext, zero component

      QEXT=0D0
      NNM=NMAX*2
      DO 204 N=1,NNM
         QEXT=QEXT+TR1(N,N)
  204 CONTINUE

!  Again for QSca, Zero component


      QSCA=0D0
      DO 213 N2=1,NMAX1
         NN2=N2+NMAX
         DO 213 N1=1,NMAX1
            NN1=N1+NMAX
            ZZ1=TR1(N1,N2)      ;  TR11(1,N1,N2)=ZZ1
            ZZ2=TI1(N1,N2)      ;  TI11(1,N1,N2)=ZZ2
            ZZ3=TR1(N1,NN2)     ;  TR12(1,N1,N2)=ZZ3
            ZZ4=TI1(N1,NN2)     ;  TI12(1,N1,N2)=ZZ4
            ZZ5=TR1(NN1,N2)     ;  TR21(1,N1,N2)=ZZ5
            ZZ6=TI1(NN1,N2)     ;  TI21(1,N1,N2)=ZZ6
            ZZ7=TR1(NN1,NN2)    ;  TR22(1,N1,N2)=ZZ7
            ZZ8=TI1(NN1,NN2)    ;  TI22(1,N1,N2)=ZZ8
            QSCA=QSCA+ZZ1*ZZ1+ZZ2*ZZ2+ZZ3*ZZ3+ZZ4*ZZ4 + &
                      ZZ5*ZZ5+ZZ6*ZZ6+ZZ7*ZZ7+ZZ8*ZZ8
  213 CONTINUE

!  ROUND THREE
!  ===========

!  Start Fourier loop

      DO 220 M=1,NMAX1

!  TMAT_R call

         call tmatrix_R                               &
     ( M, NGAUSS, NMAX, NCHECK, X, W, AN, ANN, S, SS, & ! Inputs
       PPI, PIR, PII, R, DR, DDR, DRR, DRI,           & ! Inputs
        j_bess,  y_bess,  jr_bess,  ji_bess,          & ! Inputs
       dj_bess, dy_bess, djr_bess, dji_bess,          & ! Inputs
       R11, R12, R21, R22, I11, I12, I21, I22,        & ! Outputs
       RG11,RG12,RG21,RG22,IG11,IG12,IG21,IG22,       & ! Outputs
       TR1, TI1, fail, message, trace )                 ! Outputs

!  Exception handling

         if ( fail ) then
            write(c4,'(i4)')m
            trace_2 = 'tmat_master_PLUS module: Third Call to Tmatrix_R, M = '//c4
            istatus = 2
            return
         endif

!  Count

         NM=NMAX-M+1
         NM1=NMAX1-M+1
         M1=M+1

!  QSCa calculation for this component

         QSC=0D0
         DO 214 N2=1,NM1
            NN2=N2+M-1
            N22=N2+NM
            DO 214 N1=1,NM1
               NN1=N1+M-1
               N11=N1+NM
               ZZ1=TR1(N1,N2)    ;   TR11(M1,NN1,NN2)=ZZ1
               ZZ2=TI1(N1,N2)    ;   TI11(M1,NN1,NN2)=ZZ2
               ZZ3=TR1(N1,N22)   ;   TR12(M1,NN1,NN2)=ZZ3
               ZZ4=TI1(N1,N22)   ;   TI12(M1,NN1,NN2)=ZZ4
               ZZ5=TR1(N11,N2)   ;   TR21(M1,NN1,NN2)=ZZ5
               ZZ6=TI1(N11,N2)   ;   TI21(M1,NN1,NN2)=ZZ6
               ZZ7=TR1(N11,N22)  ;   TR22(M1,NN1,NN2)=ZZ7
               ZZ8=TI1(N11,N22)  ;   TI22(M1,NN1,NN2)=ZZ8
               QSC=QSC + ( ZZ1*ZZ1+ZZ2*ZZ2+ZZ3*ZZ3+ZZ4*ZZ4 &
                       +   ZZ5*ZZ5+ZZ6*ZZ6+ZZ7*ZZ7+ZZ8*ZZ8 ) * 2D0
  214    CONTINUE

!  QExt calculation for this component

         NNM=2*NM
         QXT=0D0
         DO 215 N=1,NNM
            QXT=QXT+TR1(N,N)*2D0
  215    CONTINUE

!  Upgrade Fourier component to total

         QSCA=QSCA+QSC
         QEXT=QEXT+QXT

!  End fourier loop

  220 CONTINUE

!  Final section
!  =============

!  multiply coefficients by Lam^2/2pi

      COEFF1 = lambda * lambda * 0.5D0 / Greek_pie

!  Local Bulk values

      CSCA = QSCA*COEFF1 
      CEXT = -QEXT*COEFF1

!  Local Coefficients
!  ------------------

      if ( Do_Expcoeffs ) then

!  Main routine for coefficients

         CALL GSP ( NMAX1, LAMBDA, CSCA,              & ! Inputs
           TR11,TR12,TR21,TR22,TI11,TI12,TI21,TI22,   & ! Inputs
           AL1,AL2,AL3,AL4,BE1,BE2,LMAX,              & ! Outputs
           fail, message, trace )                       ! Outputs

!  Exception handling

         if ( fail ) then
            trace_2 = 'tmat_master module; Call to GSP Coefficients routine'
            istatus = 2
            return
         endif

!  Local maximum count

         L1M=LMAX+1
         L1MAX=MAX(L1MAX,L1M)

      endif

!       pause'1'

!  Polydisperse Summed values (Trivial, if Monodisperse)
!  ==========================

!  Bulk quantities. WGII = 1.0 for MONO

      WGII = WG1(I)
      WGXT = WGII * CEXT
      WGSC = WGII * CSCA
      CSCAT  = CSCAT  + WGSC
      CEXTIN = CEXTIN + WGXT

!  Expansion coefficients

      if ( Do_Expcoeffs ) then
         DO 250 L1=1,L1M
            ALPH1(L1)=ALPH1(L1)+AL1(L1)*WGSC
            ALPH2(L1)=ALPH2(L1)+AL2(L1)*WGSC
            ALPH3(L1)=ALPH3(L1)+AL3(L1)*WGSC
            ALPH4(L1)=ALPH4(L1)+AL4(L1)*WGSC
            BET1(L1)=BET1(L1)+BE1(L1)*WGSC
            BET2(L1)=BET2(L1)+BE2(L1)*WGSC
  250    CONTINUE
      endif

!  progress

      if (report_progress) then
         if ( do_monodisperse ) then
            write(*,'(a,i5)')'     -- Done Monodisperse, NMAX = ',NMAX
         else
            write(*,'(a,i4,a,i5)')'     -- Done PSD point # ', INK,', NMAX = ',NMAX
         endif
      endif

!  debug
!      if (INK.eq.1)pause

!  End PSD loop

56 CONTINUE

!   write(*,*)cscat, cextin
!         DO L1=1,L1M
!           write(57,'(2i4,1p6e15.5)')&
!           L1,L1M,ALPH1(L1),ALPH2(L1),ALPH3(L1),ALPH4(L1),BET1(L1),BET2(L1)
!         ENDDO
!   pause'res1'

!  Output generation for Bulk values
!  ---------------------------------

!  Regular

   WALB=CSCAT/CEXTIN
   tmat_bulk(1) = CEXTIN
   tmat_bulk(2) = CSCAT
   tmat_bulk(3) = WALB

!  Warning on WALB

   if ( WALB  > 1.0d0 ) then
      fail = .true.
      istatus = 1
      message = 'WARNING: W IS GREATER THAN 1'
      trace   = 'Output section (bulk)'
      trace_2 = 'tmat_master module' 
   endif

!  Output generation for Expansion coefficients
!  --------------------------------------------

!  Only if flag set  for Expansion coefficients output

   if ( Do_Expcoeffs ) then

!  Normalize output

      DO 510 L1=1,L1MAX
         ALPH1(L1)=ALPH1(L1)/CSCAT
         ALPH2(L1)=ALPH2(L1)/CSCAT
         ALPH3(L1)=ALPH3(L1)/CSCAT
         ALPH4(L1)=ALPH4(L1)/CSCAT
         BET1(L1)=BET1(L1)/CSCAT
         BET2(L1)=BET2(L1)/CSCAT
  510 CONTINUE

!  First, do the Hovenier and van der Mee check

      CALL HOVENR ( L1MAX,ALPH1,ALPH2,ALPH3,ALPH4,BET1,BET2, & ! Inputs
                    fail_1, fail_2, message_1, message_2 )     ! Outputs

!  Exception handling on the check

      if ( fail_1 .or. fail_2 ) then
         fail = .true.
         if ( fail_1 ) message = TRIM(message_1)
         if ( fail_2 ) message = TRIM(message_2)
         trace   = 'VanderMee/Hovenier check failed'
         trace_2 = 'tmat_master module' 
         istatus = 2
         return
      endif

!  Asymmetry parameter Assignation

      tmat_asymm = alph1(2) / 3.0d0

!  Expansion coefficients assignations

      tmat_ncoeffs = L1MAX
      DO 512 L1=1,L1MAX
         tmat_expcoeffs(L1,1) = ALPH1(L1)
         tmat_expcoeffs(L1,2) = ALPH2(L1)
         tmat_expcoeffs(L1,3) = ALPH3(L1)
         tmat_expcoeffs(L1,4) = ALPH4(L1)
         tmat_expcoeffs(L1,5) = BET1(L1)
         tmat_expcoeffs(L1,6) = BET2(L1)
  512 CONTINUE

!  F-matrix calculation

      if ( Do_Fmatrix ) then
         LMAX=L1MAX-1
         CALL MATR ( MAXNPA, NPNA, LMAX,                & ! Inputs
                     ALPH1,ALPH2,ALPH3,ALPH4,BET1,BET2, & ! Inputs
                     Tmat_FMATRIX )                       ! Outputs
      endif

!  End coefficients clause

   endif

!  Finish

   return
end subroutine tmat_master

!  End module

end module tmat_master_m
