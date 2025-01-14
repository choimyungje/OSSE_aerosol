module tmat_master_bimodal_m

!  This is the Bimodal master #1 for Tmatrix code
!    ** RT Solutions, Version 1.0, 21 December 2010
!    ** RT Solutions, Version 1.1, 07 January  2011
!    ** RT Solutions, Version 1.2, 29 March    2011
!    ** RT Solutions, Version 1.3, 24 June     2011 (mono    control)
!    ** RT Solutions, Version 1.4, 30 June     2011 (Bimodal control)
!    ** RT Solutions, Version 1.5, 25 August   2011 (Bimodal control, more)

use tmat_parameters, only : fpk => tmat_fpkind, d_one, d_zero, NPL1, MAXNPA

use tmat_master_m

!  Everything PUBLIC here
!  ----------------------

public

contains

subroutine tmat_master_bimodal ( Tmat_Verbose, &
     Do_Expcoeffs, Do_Fmatrix,                 & ! Gp 1   Inputs (Flags)
     Do_Monodisperse, Do_EqSaSphere,           & ! Gp 1   Inputs (Flags)
     Do_psd_OldStyle, psd_Index, psd_pars,     & ! Gp 1/2 Inputs (PSD)
     MonoRadius, R1, R2, FixR1R2, fraction,    & ! Gp 2   Inputs (PSD)
     np, nkmax, npna, ndgs, eps, accuracy,     & ! Gp 3   Inputs (General)
     lambda, n_real, n_imag,                   & ! Gp 4   Inputs (Optical)
     Btmat_bulk, Btmat_asymm, Btmat_ncoeffs,   & ! Outputs (Tmat)
     Btmat_expcoeffs, Btmat_Fmatrix, tmat_dist,& ! Outputs (PSD))
     fail, istatus, message, trace, trace_2, trace_3 )   ! Outputs (status)

!  List of Inputs
!  ==============

!  Flag inputs
!  -----------

!      Do_Expcoeffs      - Boolean flag for computing Expansion Coefficients
!      Do_Fmatrix        - Boolean flag for computing F-matrix at equal-angles

!      Do_Monodisperse   - Boolean flag for Doing a Monodisperse calculation
!                          If set, the PSD stuff will be turned off internally

!      Do_EqSaSphere     - Boolean flag for specifying particle size in terms
!                          of the  equal-surface-area-sphere radius

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

!      psd_Index      - Index for particle size distributions of spheres
!      psd_pars       - Parameters characterizing PSD (up to 3 allowed)

!      Monoradius     - Monodisperse radius size (Microns)

!      R1, R2         - Minimum and Maximum radii (Microns)
!      FixR1R2        - Boolean flag for allowing internal calculation of R1/R2

   implicit none

!  Boolean Input arguments
!  -----------------------

!  Verbose flag now passed, 10/19/16

   logical  , intent(in)  :: Tmat_Verbose

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

   integer  , intent(in)     :: np, ndgs(2), npna
   integer  , intent(inout)  :: nkmax(2)

!  Accuracy and aspect ratio

   real(fpk), intent(in)  :: accuracy, eps(2)

!  Optical: Wavelength, refractive index
!  -------------------------------------

   real(fpk), intent(in)  :: lambda, n_real(2), n_imag(2)

!  PSD inputs
!  ----------

!  Flag for making an internal Fix of R1 and R2
!    ( Not relevant for the Old distribution

   logical, intent(inout)  :: FixR1R2(2)

!  R1 and R2 (intent(inout))

   real(fpk), intent(inout)  :: R1(2), R2(2)

!  Monodisperse radius (input)

   real(fpk), intent(in)   :: Monoradius

!  PSD index and parameters

   integer  , intent(in)  :: psd_Index(2)
   real(fpk), intent(in)  :: psd_pars (3,2)

!  Fraction

   real(fpk), intent(in)   :: fraction

!  Output arguments --------> BIMODAL
!  ----------------

!  Bulk distribution parameters
!    1 = Extinction coefficient
!    2 = Scattering coefficient
!    3 = Single scattering albedo

   real(fpk), intent(out) :: BTmat_bulk (3)

!  Expansion coefficients and Asymmetry parameter

   integer  , intent(out) :: BTmat_ncoeffs
   real(fpk), intent(out) :: BTmat_expcoeffs (NPL1,6)
   real(fpk), intent(out) :: BTmat_asymm

!  F-matrix,  optional output

   real(fpk), intent(out) :: BTmat_Fmatrix (MAXNPA,6)

!  Distribution parameters
!    1 = Normalization
!    2 = Cross-section
!    3 = Volume
!    4 = REFF
!    5 = VEFF

   real(fpk), intent(out) :: Tmat_dist (5,2)

!  Exception handling

   logical       , intent(out) :: fail
   integer       , intent(out) :: istatus
   character*(*) , intent(out) :: trace
   character*(*) , intent(out) :: trace_2
   character*(*) , intent(out) :: trace_3
   character*(*) , intent(out) :: message

!  Local Arrays
!  ------------

!  Bulk distribution parameters
!  Expansion coefficients and Asymmetry parameter
!  F-matrix,  optional output

   real(fpk) :: Tmat1_bulk (3)
   integer   :: Tmat1_ncoeffs
   real(fpk) :: Tmat1_expcoeffs (NPL1,6)
   real(fpk) :: Tmat1_asymm
   real(fpk) :: Tmat1_Fmatrix (MAXNPA,6)

   real(fpk) :: Tmat2_bulk (3)
   integer   :: Tmat2_ncoeffs
   real(fpk) :: Tmat2_expcoeffs (NPL1,6)
   real(fpk) :: Tmat2_asymm
   real(fpk) :: Tmat2_Fmatrix (MAXNPA,6)

!  Other local variables
!  ---------------------

   integer   :: k, L
   real(fpk) :: FF1, FF2, WW1, WW2
   real(fpk) :: Csca1_FF1, Csca2_FF2, Csca_total

!  Zero the output
!  ---------------

   BTmat_bulk      = d_zero
   BTmat_Fmatrix   = d_zero
   BTmat_expcoeffs = d_zero
   BTmat_asymm     = d_zero
   BTmat_ncoeffs   = 0
   Tmat_dist       = d_zero

   FF1 = fraction
   FF2 = d_one - FF1

   trace_3 = ' '

!  Check: No Monodisperse here !
!  -----------------------------

   if ( do_monodisperse ) then
      fail = .true.; istatus = 2
      trace_3 = 'tmat_master_bimodal module: Input error: MONODISPERSE FLAG must be Off!'
      return
   endif

!  First Call
!  ---------

   k = 1 ; write(*,*)' ** Doing Tmatrix for PSD # 1 ----------------------'
   call tmat_master ( Tmat_Verbose,                  &
     Do_Expcoeffs, Do_Fmatrix,                       & ! Gp 1   Inputs (Flags)
     Do_Monodisperse, Do_EqSaSphere,                 & ! Gp 1   Inputs (Flags)
     Do_psd_OldStyle, psd_Index(k), psd_pars(:,k),   & ! Gp 1/2 Inputs (PSD)
     MonoRadius, R1(k), R2(k), FixR1R2(k),           & ! Gp 2   Inputs (PSD)
     np, nkmax(k), npna, ndgs(k), eps(k), accuracy,  & ! Gp 3   Inputs (General)
     lambda, n_real(k), n_imag(k),                   & ! Gp 4   Inputs (Optical)
     tmat1_bulk, tmat1_asymm, tmat1_ncoeffs,         & ! Outputs (Tmat)
     tmat1_expcoeffs, tmat1_Fmatrix, Tmat_dist(:,k), & ! Outputs (PSD))
     fail, istatus, message, trace, trace_2 )          ! Outputs (status)

!  Exception handling

   if ( fail ) then
      trace_3 = 'tmat_master_bimodal module: First PSD call, Warning or Error'
      if ( Istatus .eq. 2 ) return
   endif

!  Second call
!  -----------

   k = 2 ; write(*,*)' ** Doing Tmatrix for PSD # 2 ----------------------'
   call tmat_master ( Tmat_Verbose,                  &
     Do_Expcoeffs, Do_Fmatrix,                       & ! Gp 1   Inputs (Flags)
     Do_Monodisperse, Do_EqSaSphere,                 & ! Gp 1   Inputs (Flags)
     Do_psd_OldStyle, psd_Index(k), psd_pars(:,k),   & ! Gp 1/2 Inputs (PSD)
     MonoRadius, R1(k), R2(k), FixR1R2(k),           & ! Gp 2   Inputs (PSD)
     np, nkmax(k), npna, ndgs(k), eps(k), accuracy,  & ! Gp 3   Inputs (General)
     lambda, n_real(k), n_imag(k),                   & ! Gp 4   Inputs (Optical)
     tmat2_bulk, tmat2_asymm, tmat2_ncoeffs,         & ! Outputs (Tmat)
     tmat2_expcoeffs, tmat2_Fmatrix, Tmat_dist(:,k), & ! Outputs (PSD))
     fail, istatus, message, trace, trace_2 )          ! Outputs (status)

!  Exception handling

   if ( fail ) then
      trace_3 = 'tmat_master_bimodal module: Second PSD call, Warning or Error'
      if ( Istatus .eq. 2 ) return
   endif

!  Bimodal determination
!  ---------------------

!  Revision 20 September 2011
!    Correct definition for Expcoeffs/Fmatrix: WW1/WW2 in place of FF1/FF2

   Csca1_FF1  = FF1 * Tmat1_bulk(2)   
   Csca2_FF2  = FF2 * Tmat2_bulk(2)   
   Csca_total =  Csca1_FF1 + Csca2_FF2
   WW1   = Csca1_FF1 / Csca_total
   WW2   = Csca2_FF2 / Csca_total

!  @@@ Rob Fix 21 Sep 12, combined Single-scatter-albedo was wrong
   BTmat_bulk(1:2) = FF1 * Tmat1_bulk(1:2) + FF2 * Tmat2_bulk(1:2)
   BTmat_bulk(3)   = BTmat_bulk(2) / BTmat_bulk(1)
!  original code
!   BTmat_bulk(1:3) = FF1 * Tmat1_bulk(1:3) + FF2 * Tmat2_bulk(1:3)

   if ( Do_Expcoeffs ) then
      BTmat_asymm = WW1 * Tmat1_asymm + WW2 * Tmat2_asymm
      BTmat_ncoeffs = max(tmat1_ncoeffs,tmat2_ncoeffs)
      do L = 1, min(tmat1_ncoeffs,tmat2_ncoeffs)
         Btmat_expcoeffs(L,1:6) = WW1 * tmat1_expcoeffs(L,1:6) + & 
                                  WW2 * tmat2_expcoeffs(L,1:6)
      enddo
      if ( tmat1_ncoeffs .lt. tmat2_ncoeffs ) then
          do L = tmat1_ncoeffs + 1,tmat2_ncoeffs
              Btmat_expcoeffs(L,1:6) = WW2 * tmat2_expcoeffs(L,1:6)
          enddo
      else if ( tmat1_ncoeffs .gt. tmat2_ncoeffs ) then
          do L = tmat2_ncoeffs + 1,tmat1_ncoeffs
              Btmat_expcoeffs(L,1:6) = WW1 * tmat1_expcoeffs(L,1:6)
          enddo
      endif
   endif
   if ( Do_Fmatrix ) then
      do L = 1, npna
         Btmat_Fmatrix(L,1:6) = WW1 * tmat1_Fmatrix(L,1:6) + & 
                                WW2 * tmat2_Fmatrix(L,1:6)
      enddo
   endif   

!  Finish

   return
end subroutine tmat_master_bimodal

!  End module

end module tmat_master_bimodal_m
