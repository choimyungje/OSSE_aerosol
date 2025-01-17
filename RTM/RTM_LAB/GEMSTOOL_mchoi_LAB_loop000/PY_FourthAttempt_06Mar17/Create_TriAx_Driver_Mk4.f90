program Create_TriAx_Driver_Mk4

!  R. Spurr, 12-17 January 2017. PRELIMINARY.
!  R. Spurr, 3   March 2017. Third Attempt
!  R. Spurr, 6   March 2017. Fourth Attempt

!  PROVIDES a file ot User-defined TriAx Aerosols for use in GEMSTOOL

!  4 Stages to this operation:
!    (1) First take an "nc" file from the TriAx data set and convert to ascii using,
!          ncdump Database_yx1.00_zx1.00_mr1.10_mi0.0010.nc > TEMPODATA
!    (2) Extract data from the ascii file TEMPODATA created using "ncdump"
!    (3) Develop F-matrix moments for use in Gemstool
!    (4) Write up develop aerosol data into a file for use in GEMSTOOL

!  This Driver covers Stages 2-4. Stage 1 is easy and is done with a command line instruction.

!  Notes
!  =====

! New COMMENTS. 7 March 2017

!  (a) NOW USING AEROSOL PREAMBLE FILE DIRECTLY from GEMSTOOL !!!!

!      Inputs used to create aerosol file (all wvls in nm):
!      Aerosols interpolated: T
!      Aerosol RefWavelength:  500.000
!      Band Lo Wvl  :  442.000   Aero Lo Wvl  :  440.000
!      Band Hi Wvl  :  450.000   Aero Hi Wvl  :  460.000
!      Band Res     :    1.000   Aero Res     :   20.000
!      Band Num Wvls:        9   Aero Num Wvls:        2
!      PSD Index      :         4
!      PSD parameter 1:   0.70540
!      PSD parameter 2:   2.07500
!      PSD parameter 3:   0.00000

!  (b) Particle size parameter now distributed - will use integrated values
!      since x = 2.pi.radius/lambda, then use PSD on Radius, given lambda

!  (c) For reference wavelength, then only output = extinction/scattering coefficients + SSA
!      at this wavelengh. This is necessary for GEMSTOOL because we rely on a reference wavelength for
!     (usually 500 nm = 0.55 Microns) for the aerosol calculations. 
!      We also output the particle size distribution characteristics

!  (d) Ncoeffs is now set using a cutoff of 1.0d-04
!      I have experimented with a few values, and checked on the
!      accuracy of the expansions: the F-matrices are accurately reproduced in the forward scattering
!      directions, but it is difficult to get full accuracy for the two backscatter peaks.

!  User Modules
!  ============

   use Extract_TriAxData_m               ! Module for stage 2
   use Create_TriAx_for_GEMSTOOL_Mk4_m   ! Module for stage 3
   use Write_TriAxaerosol_file_m         ! Module for stage 4

   use PY_Distributions_m     ! Distributions

   implicit none

!  Precision

   integer, parameter :: fpk = SELECTED_REAL_KIND(15)

!  data file

   character*100 :: DataFile

!  TriAx data, extracted and input here
!  ====================================

!  Detailed arrays for use in a Type structure

   real(fpk)  :: TriAxData_Scatangles(500)     ! Degrees
   real(fpk)  :: TriAxData_Sizepars  (100)     

   real(fpk)  :: TriAxData_MuellerMat(100,6,500)
   real(fpk)  :: TriAxData_XsecsAsym(100,4)
   real(fpk)  :: TriAxData_Efficiency(100,4)
   real(fpk)  :: TriAxData_Distpars(100,4)

!  Mueller matrix quantities, indices 1-6 (middle dimension)

!  1:ln(P11)
!  2:P22/P11
!  3:P33/P11
!  4:P44/P11
!  5:P12/P11
!  6:P34/P11

!Triax_Efficiency(k,1) = extinction efficiency
!Triax_Efficiency(k,2) = absorption efficiency
!Triax_Efficiency(k,3) = scattering efficiency
!Triax_Efficiency(k,4) = single-scattering albedo

!Triax_XsecsAsym(k,1)  = extinction cross section
!Triax_XsecsAsym(k,2)  = absorption cross section
!Triax_XsecsAsym(k,3)  = absorption cross section
!Triax_XsecsAsym(k,4)  = asymmetry factor of phase function
	
!Triax_Distpars(k,1) = rproj  = the radius of the surface-equivalent spheres
!Triax_Distpars(k,2) = reff   = the radius of the volume-equivalent spheres
!Triax_Distpars(k,3) = parea  = the projected area
!Triax_Distpars(k,4) = volume = the volume of the particle

!  Output is the TriAx stuff as needed for GEMSTOOL
!  ================================================

!  set max_Coeffs

   integer, parameter :: Max_Coeffs = 5000

!  Distribution parameters
!  Bulk optical parameters
!    1 = Extinction coefficient
!    2 = Scattering coefficient
!    3 = Single scattering albedo
!  Asymmetry parameter and number of expansion coefficients
!  Number and value of expansion coefficients

   real(fpk)  :: TriAx_dist(5)
   real(fpk)  :: TriAx_bulk(3)
   real(fpk)  :: TriAx_asymm
   integer    :: TriAx_ncoeffs
   real(fpk)  :: TriAx_expcoeffs(6,0:max_coeffs)

!  Exception handling

   logical       :: fail, faild
   character*120 :: message

!  Local
!  =====

!  Variables directly from PREAMBLE file
!  -------------------------------------

!  Wavelength control

   Logical   :: do_aerosol_interp
   real(fpk) :: Band_Lo_Wvl    ! nm
   real(fpk) :: Band_Hi_Wvl    ! nm
   real(fpk) :: Band_Res       ! nm
   integer   :: Band_Num_Wvls 
   real(fpk) :: Aero_ref_Wvl   ! Microns
   real(fpk) :: Aero_Lo_Wvl    ! nm
   real(fpk) :: Aero_Hi_Wvl    ! nm
   real(fpk) :: Aero_Res       ! nm
   integer   :: Aero_Num_Wvls

!  PSD control

   integer   :: PSD_Index
   real(fpk) :: PSD_Pars(3)

!  distribution stuff
!  ------------------

   real(fpk) :: radii(100)
   real(fpk) :: distribution(100), Quadrature(100), distnorm
   real(fpk), parameter :: cutoff = 1.0d-04

!  Help
!  ----

   logical   :: RefWvl
   real(fpk) :: Wavelength       ! Microns
   real(fpk) :: o2pi, wo2pi
   integer   :: w, k
   character*256 :: OutFileName,Input_Preamble_File
   integer       :: OutFileUnit
   logical, parameter :: do_Debug_Write = .true.
   character*29 :: c29
   character*22 :: c22
   character*1  :: c1
   character*18 :: c18
   character*60 :: Preamble(11)

!  0. Initial  Section
!  ===================

!  PingYang Data set

   DataFile    = 'TEMPODATA'

!  Input configuration file (Preamble)

   Input_Preamble_File = 'AerFile_Preamble_Mode_02.dat'
   c1 = Input_Preamble_File(24:24)

!  read the preamble file, first to get 11 lines with character strings, for hearer

   open(1, file = Trim(Input_Preamble_File), status = 'old')
   do k = 1, 11
      read(1,'(a60)')Preamble(k)
      write(*,'(a)')Trim(Preamble(k))
   enddo
   close(1)

!  read the preamble file again, this time to get the numbers

   open(1, file = Trim(Input_Preamble_File), status = 'old')
   read(1,*) ! header of preamble file
   read(1,'(a29,L1)')  c29,do_aerosol_interp
   read(1,'(a29,f8.3)')c29,Aero_ref_Wvl
   if ( do_aerosol_interp ) then
      read(1,'(a22,f8.3,a18,f8.3)')c22,Band_Lo_Wvl  , c18,Aero_Lo_Wvl
      read(1,'(a22,f8.3,a18,f8.3)')c22,Band_Hi_Wvl  , c18,Aero_Hi_Wvl
      read(1,'(a22,f8.3,a18,f8.3)')c22,Band_Res     , c18,Aero_Res
      read(1,'(a22,i8,  a18,i8  )')c22,Band_Num_Wvls, c18,Aero_Num_Wvls
   else
      read(1,'(a22,f8.3)')c22,Band_Lo_Wvl
      read(1,'(a22,f8.3)')c22,Band_Hi_Wvl
      read(1,'(a22,f8.3)')c22,Band_Res
      read(1,'(a22,i8  )')c22,Band_Num_Wvls
   endif
   read(1,'(a29,1x,i2  )')c29,PSD_Index     ! Index
   read(1,'(a23,1x,f9.5)')c22,PSD_pars(1)   ! Parameter 1
   read(1,'(a22,1x,f9.5)')c22,PSD_pars(2)   ! Parameter 2
   read(1,'(a22,1x,f9.5)')c22,PSD_pars(3)   ! Parameter 3
   close(1)

!  CHeck file read
!write(*,*)do_aerosol_interp
!write(*,*)Aero_ref_Wvl
!write(*,*)Band_Lo_Wvl  , Aero_Lo_Wvl
!write(*,*)Band_Hi_Wvl  , Aero_Hi_Wvl
!write(*,*)Band_Res     , Aero_Res
!write(*,*)Band_Num_Wvls, Aero_Num_Wvls
!write(*,*)PSD_Index     ! Index
!write(*,*)PSD_pars(1:3)
!stop'checking file read'

!  output file (includes Mode number)

   OutFileUnit = 45
   OutFileName = 'TriAx_Output_Mk4_Mode_0'//c1//'.dat'

!  Open File, Write Header
!  -----------------------

!  open file

   open(OutFileUnit,file=Trim(OutFileName), status='replace')

!  write header, First 11 files = Preamble File

   do k = 1, 11
      write(OutFileUnit,'(a)')Trim(Preamble(k))
   enddo

!   write(OutFileUnit,'(a)')    '      Inputs used to create aerosol file (all wvls in nm):'
!   write(OutFileUnit,'(a,L2)') '      Aerosols interpolated:', do_Aerosol_Interp
!   write(OutFileUnit,'(a3,2(a19,f5.1))') '   ','   Band Lo Wvl  :   ',Band_Lo_Wvl,  '   Aero Lo Wvl  :   ',Aero_Lo_Wvl
!   write(OutFileUnit,'(a3,2(a19,f5.1))') '   ','   Band Hi Wvl  :   ',Band_Hi_Wvl,  '   Aero Hi Wvl  :   ',Aero_Hi_Wvl
!   write(OutFileUnit,'(a3,2(a19,f5.1))') '   ','   Band Res     :   ',Band_Res,     '   Aero Res     :   ',Aero_Res
!   write(OutFileUnit,'(a3,2(a19,I5))'  ) '   ','   Band Num Wvls:   ',Band_Num_Wvls,'   Aero Num Wvls:   ',Aero_Num_Wvls




   write(*,*)' ** You will be extracting TriAx data from a file called   : '//Trim(DataFile)
   write(*,*)' ** You will be writing TriAx User-defined aerosols to file: '//Trim(OutFileName)

!  Stage 2. Extract Data
!  =====================

   Call Extract_TriAxData ( Datafile, &
      TriAxData_Scatangles, TriAxData_Sizepars,   TriAxData_MuellerMat, & ! Output data
      TriAxData_XsecsAsym,  TriAxData_Efficiency, TriAxData_Distpars,   & ! output data
      Fail, message )

!  Failed

   if ( Fail ) then
      write(*,*)'Data Extraction failed. Here is the message - '
      write(*,*)Trim(message)
      stop'stop after failed data extraction !!!!!!!!'
   endif

!  debug

   if ( do_Debug_Write ) then
     open(66,file='DebugWrite/QextQscaQabsSalb.DEBUG',status='unknown')
     open(67,file='DebugWrite/CextCscaCabsAsym.DEBUG',status='unknown')
     open(68,file='DebugWrite/Phasfunc_X62.DEBUG',status='unknown')
     do k = 1, 100
       write(66,*)k, TriAxData_Sizepars(k),TriAxData_Efficiency(k,1:4)
       write(67,*)k, TriAxData_Sizepars(k),TriAxData_XsecsAsym(k,1:4)
     enddo
     do k = 1, 500
       write(68,*)k, TriAxData_Scatangles(k),exp(TriAxData_MuellerMat(62,1,k)),TriAxData_MuellerMat(62,1,k)
     enddo
     close(66); close(67) ;  close(68)
   endif

   write(*,*)'Done Stage 2: Tri-Axial Data extraction from file'

!  Stages 3/4. develop data for GEMSTOOL (3), Write to File (4)
!  ============================================================

!  1. reference wavelength
!  -----------------------

   w = 0
   RefWvl = .true.
!   Wavelength = Aero_ref_Wvl              !  Always Microns, former code
   Wavelength = Aero_ref_Wvl * 0.001d0     !  Always Microns
   O2pi = 0.5d0 / acos(-1.0d0)
   wo2pi = o2pi * Wavelength

!  Get Radii and distribution points

   do k = 1, 100
      radii(k) = WO2pi * TriAxData_Sizepars (k)
   enddo
   Call sizedis ( 100, PSD_Index, PSD_Pars, radii, 100, Distribution, message, faild )

!  FORT.44 = debug file of particle Size distribution
   do k = 1, 100
      write(44,*)k,TriAxData_Sizepars (k), radii(k),Distribution(k)
   enddo

   Quadrature(1) = Distribution(1) * 0.5d0 * ( radii(2) - radii(1) )
   do k = 2, 99
      Quadrature(k) = Distribution(k) * 0.5d0 * ( radii(k+1) - radii(k-1) )
   enddo
   Quadrature(100) = Distribution(100) * 0.5d0 * ( radii(100) - radii(99) )
   Distnorm = sum(Quadrature(1:100)) ; write(*,*)Distnorm !; stop
   Quadrature(1:100) = Quadrature(1:100) / distnorm

!  debug
!   do k = 1, 100
!      write(44,*)TriAxData_Sizepars (k), radii(k),Distribution(k)
!   enddo

   if ( faild ) then
      write(*,*)'Error from distribution module (Ref-Wav) - here is the message -->'
      write(*,*)Trim(message) ; stop'Distribution failed - stop program'
   endif

!  Call with distribution

   Call Create_TriAx_for_GEMSTOOL_Mk4 &
    ( Max_Coeffs, Cutoff, RefWvl, Quadrature,     & ! Control
      TriAxData_Scatangles, TriAxData_MuellerMat, & ! Input data
      TriAxData_XsecsAsym,  TriAxData_Distpars,   & ! Input data
      TriAx_dist, TriAx_bulk, TriAx_asymm, TriAx_ncoeffs, TriAx_expcoeffs ) ! output for GEMSTOOL

!   write to file

   Call Write_TriAxaerosol_file ( &
       Max_Coeffs, OutFileUnit, w, Wavelength, RefWvl, &
       TriAx_dist, TriAx_bulk, TriAx_asymm, TriAx_ncoeffs, TriAx_expcoeffs )

   write(*,*)'Done Stage 3/4: GEMSTOOL preparation and write-up of aerosols, Reference Wavelength'

!  2a. All other wavelengths, interpolation case
!  ---------------------------------------------

   if ( do_aerosol_interp ) then

      do w = 1, Aero_Num_Wvls

         RefWvl = .false.
         Wavelength = ( Aero_Lo_Wvl + real(w-1,fpk) * Aero_Res ) *  0.001_fpk         ! Microns
         wo2pi = o2pi * Wavelength

!  Get Radii and distribution points

         radii(1:100) = WO2pi * TriAxData_Sizepars (1:100)
         Call sizedis ( 100, PSD_Index, PSD_Pars, radii, 100, Distribution, message, faild )
         Quadrature(1) = Distribution(1) * 0.5d0 * ( radii(2) - radii(1) )
         do k = 2, 99
            Quadrature(k) = Distribution(k) * 0.5d0 * ( radii(k+1) - radii(k-1) )
         enddo
         Quadrature(100) = Distribution(100) * 0.5d0 * ( radii(100) - radii(99) )
         Distnorm = sum(Quadrature(1:100)) !; write(*,*)Distnorm ; stop
         Quadrature(1:100) = Quadrature(1:100) / distnorm
         if ( faild ) then
            write(*,*)'Error from distribution module (Aer-interp) - here is the message -->'
            write(*,*)Trim(message) ; stop'Distribution failed - stop program'
         endif

!  Call with distribution

         Call Create_TriAx_for_GEMSTOOL_Mk4 &
           ( Max_Coeffs, Cutoff, RefWvl, Quadrature,     & ! Control
             TriAxData_Scatangles, TriAxData_MuellerMat, & ! Input data
             TriAxData_XsecsAsym,  TriAxData_Distpars,   & ! Input data
             TriAx_dist, TriAx_bulk, TriAx_asymm, TriAx_ncoeffs, TriAx_expcoeffs ) ! output for GEMSTOOL

!  write to file

         Call Write_TriAxaerosol_file ( &
             Max_Coeffs, OutFileUnit, w, Wavelength, RefWvl, &
             TriAx_dist, TriAx_bulk, TriAx_asymm, TriAx_ncoeffs, TriAx_expcoeffs )

!  Progress

          write(*,*)'Done Stage 3/4: GEMSTOOL preparation and write-up of aerosols, Interp Wavelength ',Wavelength

       enddo
    endif

!  2b. All other wavelengths, NOT interpolation case
!  -------------------------------------------------

!  ONLY FOR DEBUG, INCASE YOU DECIDE NOT TO USE AEROSOL INTERPOLATION

   if ( .not. do_aerosol_interp ) then

      do w = 1, Band_Num_Wvls

         RefWvl = .false.
         Wavelength = ( Band_Lo_Wvl + real(w-1,fpk) * Band_Res ) *  0.001_fpk         ! Microns
         wo2pi = o2pi * Wavelength

!  Get Radii and distribution points

         radii(1:100) = WO2pi * TriAxData_Sizepars (1:100)
         Call sizedis ( 100, PSD_Index, PSD_Pars, radii, 100, Distribution, message, faild )
         Quadrature(1) = Distribution(1) * 0.5d0 * ( radii(2) - radii(1) )
         do k = 2, 99
            Quadrature(k) = Distribution(k) * 0.5d0 * ( radii(k+1) - radii(k-1) )
         enddo
         Quadrature(100) = Distribution(100) * 0.5d0 * ( radii(100) - radii(99) )
         Distnorm = sum(Quadrature(1:100)) !; write(*,*)Distnorm ; stop
         Quadrature(1:100) = Quadrature(1:100) / distnorm
         if ( faild ) then
            write(*,*)'Error from distribution module (No interpoilation) - here is the message -->'
            write(*,*)Trim(message) ; stop'Distribution failed - stop program'
         endif

!  Call with distribution

         Call Create_TriAx_for_GEMSTOOL_Mk4 &
           ( Max_Coeffs, Cutoff, RefWvl, Quadrature,     & ! Control
             TriAxData_Scatangles, TriAxData_MuellerMat, & ! Input data
             TriAxData_XsecsAsym,  TriAxData_Distpars,   & ! Input data
             TriAx_dist, TriAx_bulk, TriAx_asymm, TriAx_ncoeffs, TriAx_expcoeffs ) ! output for GEMSTOOL

!  write to file

         Call Write_TriAxaerosol_file ( &
             Max_Coeffs, OutFileUnit, w, Wavelength, RefWvl, &
             TriAx_dist, TriAx_bulk, TriAx_asymm, TriAx_ncoeffs, TriAx_expcoeffs )

       enddo
    endif

!  Close file

   Close(OutFileUnit)

stop
end program Create_TriAx_Driver_Mk4
