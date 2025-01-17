! ###############################################################
! #                                                             #
! #                    THE LIDORT_RRS MODEL                     #
! #                                                             #
! #      (LInearized Discrete Ordinate Radiative Transfer)      #
! #       --         -        -        -         -              #
! #                 (Rotational Raman Scatter)                  #
! #                  -          -     -                         #
! #                                                             #
! ###############################################################

! ###############################################################
! #                                                             #
! #  Author :      Robert J. D. Spurr                           #
! #                                                             #
! #  Address :     RT SOLUTIONS Inc.                            #
! #                9 Channing Street                            #
! #                Cambridge, MA 02138, USA                     #
! #                Tel: (617) 492 1183                          #
! #                                                             #
! #  Email :       rtsolutions@verizon.net                      #
! #                                                             #
! #  Version      :  2.3                                        #
! #  Release Date :  March 2011                                 #
! #                                                             #
! ###############################################################

!    #########################################################
!    #                                                       #
!    #   This Version of LIDORT_RRS comes with a GNU-style   #
!    #   license. Please read the license carefully.         #
!    #                                                       #
!    #########################################################

!  ======================================================
!  This is the module of TYPES, DIMENSIONS, and CONSTANTS
!  ======================================================

      MODULE lrrs_pars

      IMPLICIT NONE

!  Real number type definitions

      INTEGER, PARAMETER :: VLIDORT_SPKIND = SELECTED_REAL_KIND(6)
      INTEGER, PARAMETER :: VLIDORT_DPKIND = SELECTED_REAL_KIND(15)
      INTEGER, PARAMETER :: FPK = VLIDORT_DPKIND

!  DIMENSIONS
!  ==========

!  Basic: Physics Dimensioning
!  ---------------------------

!  Maximum number of spectral points
!  MONO: Should always be set to (at least) number of shifts + 1
!  BIN:  Can be less
      INTEGER, PARAMETER :: MAX_POINTS = 234
!      INTEGER, PARAMETER :: MAX_POINTS = 234
!      INTEGER, PARAMETER :: MAX_POINTS = 500
!      INTEGER, PARAMETER :: MAX_POINTS = 1500
!      INTEGER, PARAMETER :: MAX_POINTS = 600

!  Maximum number of layers

      INTEGER, PARAMETER :: MAX_LAYERS = 25

!  Maximum number of fine layers

      INTEGER, PARAMETER :: MAX_FINE_LAYERS = 4

!  Maximum number of MS phase function moments
!    Can set this to twice the number of streams

      INTEGER, PARAMETER :: MAX_MOMENTS = 500
!      INTEGER, PARAMETER :: MAX_MOMENTS = 432

!  Maximum number of INPUT phase function moments
!  Should be at least 2N

      INTEGER, PARAMETER :: MAX_MOMENTS_INPUT = 500
!      INTEGER, PARAMETER :: MAX_MOMENTS_INPUT = 432

!  Maximum number of RRS bins and shifts
      ! INTEGER, PARAMETER :: MAX_BINS = 32001
      INTEGER, PARAMETER :: MAX_BINS = 234  ! Mono setting
!      INTEGER, PARAMETER :: MAX_BINS = 80
      ! INTEGER, PARAMETER :: MAX_BINS = 50

      INTEGER, PARAMETER :: MAX_SHIFTS = 233
      ! INTEGER, PARAMETER :: MAX_SHIFTS = 32000
      
!  Basic: RT Dimensioning
!  ----------------------

!  Maximum number of discrete ordinates

      INTEGER, PARAMETER :: MAX_STREAMS = 16

!  Maximum numbers of off-boundary and total output levels

      INTEGER, PARAMETER :: MAX_PARTIALS_LOUTPUT = 1
      INTEGER, PARAMETER :: MAX_LOUTPUT = 1

!  Maximum numbers of user defined zeniths and azimuths

      INTEGER, PARAMETER :: MAX_USER_STREAMS = 1
      INTEGER, PARAMETER :: MAX_USER_RELAZMS = 1

!  Upwelling and downwelling

      INTEGER, PARAMETER :: MAX_DIRECTIONS = 2

!  Maximum number of BRDF azimuth streams
!    Set this to a low number if you are not using the BRDF facility

      INTEGER, PARAMETER :: MAX_STREAMS_BRDF = 1
!      INTEGER, PARAMETER :: MAX_STREAMS_BRDF = 51

!  Maximum number of BRDF parameters

      INTEGER, PARAMETER :: MAX_BRDF_PARAMETERS = 3

!  Maximum number of weighting functions

      INTEGER, PARAMETER :: MAX_PARS = 4

!  Messages dimensioning
!  ---------------------

      INTEGER, PARAMETER :: MAX_MESSAGES = 100

!  Derived Dimensioning
!  --------------------

!  NK storage (for linearization arrays)

      INTEGER, PARAMETER :: MAX_LAYERS_NK = &
                            MAX_LAYERS * ( MAX_LAYERS + 3 ) / 2
      INTEGER, PARAMETER :: MAX_LAYERS_SQ = MAX_LAYERS * MAX_LAYERS

!  Max Geometries

      INTEGER, PARAMETER :: MAX_GEOMETRIES = &
                            MAX_USER_STREAMS * MAX_USER_RELAZMS

!  Stream numbers

      INTEGER, PARAMETER :: MAX_2_STREAMS   = 2*MAX_STREAMS
      INTEGER, PARAMETER :: MAX_OUT_STREAMS = MAX_USER_STREAMS+MAX_STREAMS
      INTEGER, PARAMETER :: MAX_STREAMS_P1  = MAX_STREAMS + 1

!  Maximum Number of additional sourceterms in the RTS

      INTEGER, PARAMETER :: MAX_EXPONENTS = &
                            ( MAX_2_STREAMS + 1 ) * MAX_BINS + 1
      INTEGER, PARAMETER :: MAX_SOLUTIONS = &
                            ( MAX_2_STREAMS + 2 ) * MAX_BINS + 1

!  Dimensioning for the boundary value problem

      INTEGER, PARAMETER :: MAX_TOTAL     = MAX_LAYERS * MAX_2_STREAMS
      INTEGER, PARAMETER :: MAX_BANDTOTAL = 9 * MAX_STREAMS - 2

!  CONSTANTS
!  =========

!  Version numbers

      CHARACTER (LEN=8), PARAMETER :: LRRS_VERSION_NUMBER = 'LRRS_2.3'

!  File i/o unit numbers
!  ---------------------

      INTEGER, PARAMETER :: LRRS_INUNIT   = 21
      INTEGER, PARAMETER :: LRRS_SCENUNIT = 21
      INTEGER, PARAMETER :: LRRS_FUNIT    = 23
      INTEGER, PARAMETER :: LRRS_RESUNIT  = 24
      INTEGER, PARAMETER :: LRRS_ERRUNIT  = 25
      INTEGER, PARAMETER :: LRRS_DBGUNIT  = 71

!  Format constants
!  ----------------

      CHARACTER (LEN=*), PARAMETER :: &
        FMT_HEADING = '( / T6, ''-----> '', A, /)'

      CHARACTER (LEN=*), PARAMETER :: &
        FMT_INTEGER = '(T6, A, T58, I10)'

      CHARACTER (LEN=*), PARAMETER :: &
        FMT_REAL    = '(T6, A, T58, 1PG14.6)'

      CHARACTER (LEN=*), PARAMETER :: &
        FMT_CHAR    = '(T6, A, T48, A20)'

      CHARACTER (LEN=*), PARAMETER :: &
        FMT_SECTION = '( / T6, ''****** '', A, /)'

!  Numbers
!  -------

      REAL(FPK), PARAMETER :: ONE = 1.0D0, ZERO = 0.0D0, &
                                     ONEP5 = 1.5D0
      REAL(FPK), PARAMETER :: TWO = 2.0D0, THREE = 3.0D0, &
                                     FOUR = 4.0D0
      REAL(FPK), PARAMETER :: QUARTER = 0.25D0, HALF = 0.5D0
      REAL(FPK), PARAMETER :: MINUS_ONE = -ONE
      REAL(FPK), PARAMETER :: MINUS_TWO = -TWO
      REAL(FPK), PARAMETER :: DEG_TO_RAD = 1.7453292519943D-02
      REAL(FPK), PARAMETER :: PIE = 180.0D0*DEG_TO_RAD
      REAL(FPK), PARAMETER :: PI2 = 2.0D0 * PIE
      REAL(FPK), PARAMETER :: PI4 = 4.0D0 * PIE
      REAL(FPK), PARAMETER :: PIO2 = HALF * PIE
      REAL(FPK), PARAMETER :: PIO4 = QUARTER * PIE
      REAL(FPK), PARAMETER :: EPS3 = 0.001D0
      REAL(FPK), PARAMETER :: EPS4 = 0.0001D0
      REAL(FPK), PARAMETER :: EPS5 = 0.00001D0
      REAL(FPK), PARAMETER :: SMALLNUM = 1.0D-15
      REAL(FPK), PARAMETER :: BIGEXP = 32.0D0

!  Toggles
!  -------

!  Control for Using L'Hopital's Rule

      REAL(FPK), PARAMETER :: HOPITAL_TOLERANCE = EPS5

!  Control for limits of single scatter albedo

      REAL(FPK), PARAMETER :: OMEGA_SMALLNUM = 1.0D-06

!  Optical depth small number limits
!  ---------------------------------

!  Limits changed to 88 from 32, 18 November 2005, R. Spurr

!  Control for limits of extinction optical depth along solar path

      REAL(FPK), PARAMETER :: MAX_TAU_SPATH = 88.0D0
!      REAL(FPK), PARAMETER :: MAX_TAU_SPATH = 32.0D0

!  Control for limits of extinction optical depth along USER paths

      REAL(FPK), PARAMETER :: MAX_TAU_UPATH = 88.0D0
!      REAL(FPK), PARAMETER :: MAX_TAU_UPATH = 32.0D0

!  Control for limits of extinction optical depth along QUADRATURE paths

      REAL(FPK), PARAMETER :: MAX_TAU_QPATH = 88.0D0
!      REAL(FPK), PARAMETER :: MAX_TAU_QPATH = 32.0D0

!  Error indices
!  -------------

      INTEGER, PARAMETER :: LRRS_SERIOUS = 2
      INTEGER, PARAMETER :: LRRS_WARNING = 1
      INTEGER, PARAMETER :: LRRS_SUCCESS = 0

!  Directional indices
!  -------------------

      INTEGER, PARAMETER :: UPIDX = 1
      INTEGER, PARAMETER :: DNIDX = 2

!  Surface Type indices
!  --------------------

!  These refer to the BRDF kernel functions currently included.

      INTEGER, PARAMETER :: LAMBERTIAN_IDX  = 1
      INTEGER, PARAMETER :: HAPKE_IDX       = 2
      INTEGER, PARAMETER :: RAHMAN_IDX      = 3
      INTEGER, PARAMETER :: COXMUNK_IDX     = 4

      INTEGER, PARAMETER :: MAXBRDF_IDX = COXMUNK_IDX

!  End of Module.

      END MODULE lrrs_pars

