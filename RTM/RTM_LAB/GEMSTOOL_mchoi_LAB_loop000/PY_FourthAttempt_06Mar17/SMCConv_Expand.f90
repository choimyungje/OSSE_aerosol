module SMCConv_Expand_m

public

contains

SUBROUTINE SMCConv_Expand &
      ( max_InAngles, Max_Coeffs, n_InAngles, ncoeffs, nstokes, InCosines, expcoeffs, Fmatrices )

!  Stand-alone routine to expand Fmatrices from expansion coefficients
!  Based on the Meerhoff Mie code (as found in RTSMie package), and adapted

!  Use the expansion coefficients of the scattering matrix in 
!  generalized spherical functions to expand F matrix

   implicit none

!  precision

   integer, parameter :: dpk = SELECTED_REAL_KIND(15)

!  input

   INTEGER           , INTENT (IN) :: max_InAngles, Max_Coeffs
   INTEGER           , INTENT (IN) :: n_InAngles, ncoeffs, nstokes
   REAL    (KIND=dpk), INTENT (IN) :: InCosines(Max_InAngles)
   REAL    (KIND=dpk), INTENT (IN) :: expcoeffs(0:Max_Coeffs,6)

!  output, already initialized

   REAL    (KIND=dpk), INTENT (OUT) :: FMatrices(Max_InAngles,6)

!  local variables

   REAL    (KIND=dpk) :: P00(2), P02(2), P2p2(2), P2m2(2)
   REAL    (KIND=dpk) :: fmat(6)

   real(dpk), parameter :: d_zero  = 0.0_dpk, d_one  = 1.0_dpk
   real(dpk), parameter :: d_half  = 0.5_dpk, d_two  = 2.0_dpk
   real(dpk), parameter :: d_three = 3.0_dpk, d_four = 4.0_dpk

   INTEGER            :: l, k, lnew, lold, itmp
   INTEGER            :: index_11, index_12, index_22, index_33, index_34, index_44 
   REAL    (KIND=dpk) :: dl, dl1, qroot6, fac1, fac2, uuu, FL2, FLL1, PERLL4, Q, WFACT, &
                         sql4, sql41, tmp1, tmp2, GK11, GK12, GK34, GK44, GK22, GK33, SUM23, DIF23

!  Initialization

   qroot6 = -0.25_dpk*SQRT(6.0_dpk)
   FMatrices = d_zero

!  Indices

   index_11 = 1
   index_22 = 2
   index_33 = 3
   index_44 = 4
   index_12 = 5
   index_34 = 6

!  START LOOP OVER IN COSINES

   DO K = 1, N_InAngles

!  Cosine of the scattering angle
      
      FMAT = D_ZERO
      UUU = InCosines(N_InAngles+1-k)

!  START LOOP OVER THE COEFFICIENT INDEX L
!  FIRST UPDATE GENERALIZED SPHERICAL FUNCTIONS, THEN CALCULATE COEFS.
!  LOLD AND LNEW ARE POINTER-LIKE INDICES USED IN RECURRENCE

      LNEW = 1
      LOLD = 2

      DO L = 0, NCOEFFS

        DL   = REAL(L,dpk)
        DL1  = DL - d_one

!  SET THE LOCAL COEFFICIENTS
!   44 AND 34 ARE NOT REQUIRED WITH NATURAL SUNLIGHT (DEFAULT HERE)
!   22 AND 33 REQUIRED FOR NON-MIE SPHEROIDAL PARTICLES

        GK11 = EXPCOEFFS(L,1)
        IF ( NSTOKES .GT. 1 ) THEN
          GK22 = + EXPCOEFFS(L,2)
          GK33 = + EXPCOEFFS(L,3)
          GK44 = + EXPCOEFFS(L,4)
          GK12 = + EXPCOEFFS(L,5)
          GK34 = - EXPCOEFFS(L,6)
        ENDIF

!  FIRST MOMENT

        IF ( L .EQ. 0 ) THEN

!  ADDING PAPER EQS. (76) AND (77) WITH M=0
!   ADDITIONAL FUNCTIONS P2M2 AND P2P2 ZERO FOR M = 0

          P00(LOLD) = d_one
          P00(LNEW) = d_zero
          P02(LOLD) = d_zero
          P02(LNEW) = d_zero
          P2P2(LOLD) = d_zero
          P2P2(LNEW) = d_zero
          P2M2(LOLD) = d_zero
          P2M2(LNEW) = d_zero

        ELSE

          FAC1 = (d_two*DL-d_one)/DL
          FAC2 = DL1/DL

! ADDING PAPER EQ. (81) WITH M=0

          P00(LOLD) = FAC1*UUU*P00(LNEW) - FAC2*P00(LOLD)

        END IF

        IF ( L .EQ. 2 ) THEN

! ADDING PAPER EQ. (78)
! SQL4 CONTAINS THE FACTOR DSQRT((L+1)*(L+1)-4) NEEDED IN
! THE RECURRENCE EQS. (81) AND (82)

          P02(LOLD) = QROOT6*(d_one-UUU*UUU)
          P02(LNEW) = d_zero
          SQL41     = d_zero

!  INTRODUCE THE P2P2 AND P2M2 FUNCTIONS FOR L = 2

          P2P2(LOLD)= 0.25_dpk*(d_one+UUU)*(d_one+UUU)
          P2M2(LOLD)= 0.25_dpk*(d_one-UUU)*(d_one-UUU)

        ELSE IF ( L .GT. 2) THEN

! ADDING PAPER EQ. (82) WITH M=0

          SQL4  = SQL41
          SQL41 = SQRT(DL*DL-d_four)
          TMP1  = (d_two*DL-d_one)/SQL41
          TMP2  = SQL4/SQL41
          P02(LOLD) = TMP1*UUU*P02(LNEW) - TMP2*P02(LOLD)

!  INTRODUCE THE P2P2 AND P2M2 FUNCTIONS FOR L > 2

          FL2 = d_two * DL - d_one
          FLL1 = DL * DL1
          PERLL4=d_one/(DL1*SQL41**d_two)
          Q     = DL  * ( DL1*DL1 - d_four)
          WFACT = FL2 * ( FLL1 * UUU - d_four )
          P2P2(LOLD) = (WFACT*P2P2(LNEW) - Q*P2P2(LOLD)) * PERLL4
          WFACT = FL2 * ( FLL1 * UUU + d_four )
          P2M2(LOLD) = (WFACT*P2M2(LNEW) - Q*P2M2(LOLD)) * PERLL4

        END IF

! SWITCH INDICES SO THAT LNEW INDICATES THE FUNCTION WITH
! THE PRESENT INDEX VALUE L, THIS MECHANISM PREVENTS SWAPPING
! OF ENTIRE ARRAYS.

        ITMP = LNEW
        LNEW = LOLD
        LOLD = ITMP

! NOW ADD THE L-TH TERM TO THE SCATTERING MATRIX.
! SEE DE HAAN ET AL. (1987) EQS. (68)-(73).

! SECTION FOR RANDOMLY-ORIENTED SPHEROIDS, ADDED 05 OCTOBER 2010
!  R. SPURR AND V. NATRAJ

        IF ( L.LE.NCOEFFS ) THEN
          FMAT(INDEX_11) = FMAT(INDEX_11) + GK11 * P00(LNEW)
          FMAT(INDEX_12) = FMAT(INDEX_12) + GK12 * P02(LNEW)
          SUM23 = GK22 + GK33
          DIF23 = GK22 - GK33
          FMAT(INDEX_22) = FMAT(INDEX_22) + SUM23 * P2P2(LNEW)
          FMAT(INDEX_33) = FMAT(INDEX_33) + DIF23 * P2M2(LNEW)
          FMAT(INDEX_44) = FMAT(INDEX_44) + GK44 * P00(LNEW)
          FMAT(INDEX_34) = FMAT(INDEX_34) + GK34 * P02(LNEW)
        ENDIF

!  END COEFFICIENT LOOP

      END DO

!   THIS MUST BE DONE AFTER THE MOMENT LOOP.

      FMAT(INDEX_22) = d_half * ( FMAT(INDEX_22) + FMAT(INDEX_33) )
      FMAT(INDEX_33) = FMAT(INDEX_22) - FMAT(INDEX_33)

! REMEMBER FOR MIE SCATTERING : F11 = F22 AND F33 = F44
!  THIS CODE IS NO LONGER REQUIRED, AS WE HAVE INTRODUCED CODE NOW
!   FOR RANDOMLY ORIENTED SPHEROIDS. THE SYMMETRY SHOULD STILL OF
!   COURSE BE PRESENT FOR THE MIE PARTICLES, SO THIS WILL BE A
!   CHECK ON THE NEW CODE. R. SPURR AND V. NATRAJ,, 20 MARCH 2006
!        FMAT(INDEX_22) = FMAT(INDEX_11)
!        FMAT(INDEX_33) = FMAT(INDEX_44)

!  Assign output

      FMatrices(K,1:6) = FMAT(1:6)

!  End geometry loop

   ENDDO

!  Done

  RETURN
END SUBROUTINE  SMCConv_Expand

!  End module

End Module SMCConv_Expand_m

