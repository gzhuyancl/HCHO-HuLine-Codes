PROGRAM OVERSAMPLING_AREA_DAILY_REGRIDDING

        !==============================================================================
        ! Cakecut module is from Kai Yang (kaiyang@umd.edu)
        ! Applied by Lei Zhu (leizhu@fas.harvard.edu) to do satellite oversampling
        ! 12/23/14
	! Changes:
	! Now it's able to process daily regridding, 05/11/20 (Lei Zhu)
        ! Propagation of uncertainty was added by Dakang Wang, 02/22/22 (Dakang Wang)

        !==============================================================================
        ! How to use:
        ! Compile: gfortran -o Oversampling_Daily_Regridding.x cakecut_m.f90 tools_m.f90 
	!                      Oversampling_Daily_Regridding.f90
        ! Run: ./run_oversampling.sh

        !==============================================================================
        ! Modules
        USE cakecut_m
        USE tools_m

        IMPLICIT NONE

        !==============================================================================
        ! Variables

        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Input and output dirs
        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Input and output file names
        CHARACTER*200 Input_Filename, Output_Filename
        ! Input file unit
        INTEGER :: In_Unit

        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Satellite pixels information read from the input file
        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Total number of pixels
        INTEGER :: NPIXELS
        ! Lat and Lon read from the input file
        ! 4 corners and the center
        REAL,    ALLOCATABLE :: LAT(:,:), LON(:,:)
        ! Columns read from the input
        REAL,    ALLOCATABLE :: VCD(:), VCD_UNC(:)
        ! Information read from the input file
	REAL    :: TEMP(12)

        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Single pixel
        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! The area of the pixel
        REAL    :: A
        ! Lat and Lon of 4 corners read from the input 
        REAL    :: Lat_o(4), Lon_o(4)
        ! Sorted Lat and Lon of the 4 corners, now it's in clockwise order
        INTEGER :: id(4)
        REAL    :: Lat_r(4), Lon_r(4)

        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Related to cakecut scripts
        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Single pixel
        TYPE( POLYGON )                 :: pixel 
        ! Results from Horizontal and Veritical cut 
        TYPE( POLYGON ), DIMENSION(500) :: sub_pixels, final_pixels 
        INTEGER :: id_all, id_sub, id_final, n_sub_pixels, n_final_pixels
        ! Overlapped area
        REAL    :: temp_area
        ! Total area of the pixel, will be compared with A
        ! to test area conservativeness
        REAL    :: pixel_area

        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Domain parameters
        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! 4 edges of the domain
        REAL    :: Lat_low, Lat_up, Lon_left, Lon_right
        ! Resolution, use 0.5 
        REAL    :: Res
        ! # of rows (lat) and cols (lon) of the domain
        INTEGER :: NROWS, NCOLS
 
        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Results
        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Overlapped area in each cell
        REAL,    ALLOCATABLE :: Sub_Area(:,:)
        ! Sum at each step (pixel)
        REAL,    ALLOCATABLE :: Sum_Above(:,:), Sum_Below(:,:)
        REAL,    ALLOCATABLE :: Sum_Above_UNC(:,:), Sum_Below_UNC(:,:)
        ! Count, how many pixels have contribution to this cell
        INTEGER, ALLOCATABLE :: Pixels_count(:,:)
        ! Overlapped area and error weighted final results
        REAL,    ALLOCATABLE :: Average(:,:)
        REAL,    ALLOCATABLE :: Average_UNC(:,:)

        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        ! Loop index and other
        !+++++++++++++++++++++++++++++++++++++++++++++++++++++++
        INTEGER :: i, row, col, p
	INTEGER :: N_BAD, N_AREA, N_IDC

        !==============================================================================
        !==============================================================================
        !==============================================================================
        ! User input, passed from run_template.sh
        !==============================================================================
        !==============================================================================
        !==============================================================================

	Input_Filename  = "Merge_temp"
	Output_Filename = "L3_Daily_temp"

        READ ( 5, *     ) Lat_low
        READ ( 5, *     ) Lat_up
        READ ( 5, *     ) Lon_left
        READ ( 5, *     ) Lon_right
        READ ( 5, *     ) Res

        !==============================================================================
        !==============================================================================
        !==============================================================================
        ! Read satellite pixels
        !==============================================================================
        !==============================================================================
        !==============================================================================

        ! Set unit
        In_Unit = 100

        ! Set pixel index
        p = 0

        ! Open daily pixels file
        Input_Filename = TRIM(Input_Filename)
        CALL Check_File(Input_Filename, In_Unit)
11      CONTINUE
        p = p + 1
        READ(In_Unit, *, END=12, ERR=12)
        GOTO 11
12      CONTINUE
        p = p - 1

        ! Find the number of total pixels
        NPIXELS = p

        !PRINT*, " ----------------------------------------------------------"
        !PRINT*, "Total pixels : ", NPIXELS

        IF(NPIXELS==0) THEN
          GOTO 60
        ENDIF

        ! Allocate arraies
        ALLOCATE ( LAT     (NPIXELS, 5) )
        ALLOCATE ( LON     (NPIXELS, 5) )
        ALLOCATE ( VCD     (NPIXELS) )
        ALLOCATE ( VCD_UNC (NPIXELS) )

        ! Re-read the daily file, and store arrries
        p = 0
        REWIND(In_Unit)
13      CONTINUE
        p = p + 1
        READ(In_Unit,*,end=14,err=14) TEMP(1:12)
	LAT(p,1:5) = TEMP(1:5)  ! Center, 4 Concers
        LON(p,1:5) = TEMP(6:10) ! Center, 4 Concers
        VCD(p)     = TEMP(11)   ! VCD
	VCD_UNC(p) = TEMP(12)   ! VCD error
        GOTO 13
14      CONTINUE
        p = p - 1 
        CLOSE(In_Unit)

        !==============================================================================
        !==============================================================================
        !==============================================================================
        ! Get domain parameters based on the input information
        !==============================================================================
        !==============================================================================
        !==============================================================================

        ! Get # rows and cols of the domain
        NROWS = ( Lat_up    - Lat_low  ) / Res
        NCOLS = ( Lon_right - Lon_left ) / Res

        ! Allocate arraies and initializ them
        ALLOCATE ( Sub_Area(NROWS, NCOLS)     )
        ALLOCATE ( Sum_Above(NROWS, NCOLS)    )
        ALLOCATE ( Sum_Below(NROWS, NCOLS)    )
        ALLOCATE ( Sum_Above_UNC(NROWS, NCOLS))
        ALLOCATE ( Sum_Below_UNC(NROWS, NCOLS))
        ALLOCATE ( Average(NROWS, NCOLS)      )
        ALLOCATE ( Average_UNC(NROWS, NCOLS)  )
        ALLOCATE ( Pixels_count(NROWS, NCOLS) )

        Sub_Area     = 0.0D0
        Sum_Above    = 0.0D0
        Sum_Below    = 0.0D0
        Sum_Above_UNC    = 0.0D0
        Sum_Below_UNC    = 0.0D0
        Average      = 0.0D0
        Average_UNC      = 0.0D0
        Pixels_count = 0
	N_BAD        = 0
	N_AREA       = 0
	N_IDC        = 0

        !==============================================================================
        !==============================================================================
        !==============================================================================
        ! Loop pixels, get overlapped area using Cakecut functions
        !==============================================================================
        !==============================================================================
        !==============================================================================

        !PRINT*, "------------------------------------------------------"

        DO p = 1, NPIXELS

	!print*, p
        
	! Valid pixel
	IF(VCD_UNC(p) == -9999 .OR. VCD(p)   == -9999 .OR. LON(p,1) == -9999 .OR. LON(p,2) == -9999 .OR. &
	   LON(p,3) == -9999 .OR. LON(p,4) == -9999 .OR. LON(p,5) == -9999 .OR. &
	   LAT(p,1) == -9999 .OR. LAT(p,2) == -9999 .OR. LAT(p,3) == -9999 .OR. & 
	   LAT(p,4) == -9999 .OR. LAT(p,5) == -9999) THEN
	  !PRINT*, "  - Sikp bad pixel at: ", p
	  N_BAD = N_BAD + 1
	  CYCLE
	ENDIF

        ! Print process
        !IF(MOD(p, 1000000)==0) THEN
        !    PRINT*,"    Processing (%): ", NINT(REAL(p)/NPIXELS*100)
        !ENDIF

        Lat_r = 0.0D0
        Lon_r = 0.0D0

	! Add 360 degrees to handel pixels crossing the Internatioanl Date Change Line
	IF( (MAXVAL(LON(p,2:5)) > 90.0D0) .AND. (MINVAL(LON(p,2:5)) < -90.0D0) ) THEN
	  !PRINT*, "  - Handel pixel crossing IDC line at: ", p
	  N_IDC = N_IDC + 1
	  IF(LON(p,2)<0) THEN
	    LON(p,2) = LON(p,2) + 360.0D0
	  ENDIF
	  IF(LON(p,3)<0) THEN
	    LON(p,3) = LON(p,3) + 360.0D0
	  ENDIF
	  IF(LON(p,4)<0) THEN
	    LON(p,4) = LON(p,4) + 360.0D0
	  ENDIF
	  IF(LON(p,5)<0) THEN
	    LON(p,5) = LON(p,5) + 360.0D0
	  ENDIF
	ENDIF
        Lon_o = LON(p,2:5)
        Lat_o = LAT(p,2:5)

        ! Arrange the corners so that it's in colockwise order
        id = -9999
        CALL Clockwise_Sort( Lon_o, Lat_o, id )

        ! Check for bad pixels
        IF( SUM(id) /= 10 ) THEN
          PRINT*, "Bad pixel: ", p
          PRINT*, Lon_o, Lat_o
          PRINT*, Lon_r, Lat_r
          PRINT*, id
          !STOP
	  CYCLE
        ENDIF

        ! Get the colockwise-ordered 4 corners
        DO i = 1, 4
          Lon_r(i) = Lon_o(id(i))
          Lat_r(i) = Lat_o(id(i))
        ENDDO

        !PRINT*,"Pixel: ", p, Lon_r, Lat_r

        ! Arrange the pixel corners in the grids
        pixel%nv = 4

        DO i = 1, 4
          pixel%vList(i,1:2) = (/ (Lon_r(i)-Lon_left)/Res, (Lat_r(i)-Lat_low)/Res /) 
        ENDDO
        
        ! Get the area of the pixel
        CALL Cal_Quard_Area(Lon_r,Lat_r,A)

        ! Used for the next step
        id_all = 0
        pixel_area = 0.0d0

        ! Perform Horizontal cut first at the integer grid lines
        n_sub_pixels = HcakeCut( pixel, sub_pixels)

        ! Then perform Vertical cut for each sub pixel obtainted 
        ! from the Horizontal cut at the integer grid lines
        DO id_sub = 1, n_sub_pixels
          n_final_pixels = VcakeCut( sub_pixels(id_sub), final_pixels )
          DO id_final = 1, n_final_pixels
            id_all = id_all + 1
            temp_area = area2(final_pixels(id_final))*0.5d0*Res*Res
            pixel_area = pixel_area + temp_area
            !DO i = 1, final_pixels(id_final)%nv
            !  WRITE(*,'(A,F10.3,A,F10.3,A)') '{', final_pixels(id_final)%vList(i,1),',', &
            !                                      final_pixels(id_final)%vList(i,2),'},' 
            !ENDDO
            row = FLOOR(MINVAL(final_pixels(id_final)%vList(1:final_pixels(id_final)%nv,2))) + 1
            col = FLOOR(MINVAL(final_pixels(id_final)%vList(1:final_pixels(id_final)%nv,1))) + 1
            !WRITE(*,*) 'id =', id_all, ', aera=',temp_area, ', row=', row, ',col=',col

            ! Get the overlaped area between the pixel and each cell
            Sub_Area(row,col) = temp_area
            ! Sum weighted value and weights
            Pixels_count(row,col) = Pixels_count(row,col) + 1
	    !   -- VCD
            Sum_Above(row,col) = Sum_Above(row,col) + temp_area/A*VCD(p)
            Sum_Below(row,col) = Sum_Below(row,col) + temp_area/A
            !   -- VCD_UNC
            Sum_Above_UNC(row,col) = Sum_Above_UNC(row,col) + (temp_area/A*VCD_UNC(p))**2
            Sum_Below_UNC(row,col) = Sum_Below_UNC(row,col) + temp_area/A
          ENDDO
        ENDDO
        
        ! Check area consvertiveness
        IF( ABS(A-pixel_area)/A >=0.5  ) THEN
          !PRINT*, "------------------------------------------------------"
          !PRINT*, "  -Area not conservative at pixel:", p, A, pixel_area    
          !PRINT*, Lon_o, Lat_o
          !PRINT*, Lon_r, Lat_r
	  N_AREA = N_AREA + 1
        ENDIF

        ! End loop pixels
        ENDDO 

        !==============================================================================
        !==============================================================================
        !==============================================================================
        ! Get weigthed average and save output
        !==============================================================================

        ! Open output file
        OPEN(99,file=TRIM(Output_Filename))

        ! Save
        DO row = 1, NROWS
        DO Col = 1, NCOLS
          IF( Sum_Above(row,col)/=0 .AND. Sum_Below(row,col)/=0 .AND. Sum_Above_UNC(row,col)/=0 &
                  .AND. Sum_Below_UNC(row,col)/=0 ) THEN
            Average(row,col)= Sum_Above(row,col)/Sum_Below(row,col)
            Average_UNC(row,col)= sqrt(Sum_Above_UNC(row,col)/(Sum_Below_UNC(row,col))**2)     
            WRITE(99,'(2I6,6E15.6,I10)') row, col, Sum_Above(row,col), Sum_Below(row,col), &
                                       Average(row,col), Sum_Above_UNC(row,col), Sum_Below_UNC(row,col), &
                                       Average_UNC(row,col), Pixels_count(row,col)
          ENDIF
        ENDDO
        ENDDO

        ! Close output
        CLOSE(99)

        ! Print pixels number and domain parameters again for reference
        !PRINT*, " -----------------------------------------------------"
        PRINT*, "       Total pixels :", NPIXELS
        PRINT*, "       - Bad pixels :", N_BAD
        PRINT*, "       - Bad Area   :", N_AREA
        PRINT*, "       - IDC pixels :", N_IDC

        !==============================================================================
        !==============================================================================
        !==============================================================================
        ! Free memories
        !==============================================================================
        !==============================================================================
        !==============================================================================

        IF ( ALLOCATED( LAT          ) ) DEALLOCATE( LAT          )
        IF ( ALLOCATED( LON          ) ) DEALLOCATE( LON          )
        IF ( ALLOCATED( VCD          ) ) DEALLOCATE( VCD          )
        IF ( ALLOCATED( VCD_UNC      ) ) DEALLOCATE( VCD_UNC      )
        IF ( ALLOCATED( Sub_Area     ) ) DEALLOCATE( Sub_Area     )
        IF ( ALLOCATED( Sum_Above    ) ) DEALLOCATE( Sum_Above    )
        IF ( ALLOCATED( Sum_Below    ) ) DEALLOCATE( Sum_Below    )
        IF ( ALLOCATED( Sum_Above_UNC    ) ) DEALLOCATE( Sum_Above_UNC    )
        IF ( ALLOCATED( Sum_Below_UNC    ) ) DEALLOCATE( Sum_Below_UNC    )
        IF ( ALLOCATED( Pixels_count ) ) DEALLOCATE( Pixels_count )
        IF ( ALLOCATED( Average      ) ) DEALLOCATE( Average      )
        IF ( ALLOCATED( Average_UNC      ) ) DEALLOCATE( Average_UNC      )

60      CONTINUE ! No pixels        

END PROGRAM OVERSAMPLING_AREA_DAILY_REGRIDDING
