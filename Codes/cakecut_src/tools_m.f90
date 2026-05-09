! Contains functions and subroutines 
! developed by Lei Zhu (leizhu@fas.harvard.edu) in his research
! Last updated: 01/05/15

MODULE tools_m

        IMPLICIT NONE

        CONTAINS

          !*************************************************************
          !*************************************************************
          ! Check file exist or not,
          ! If exist open it, else stop with error message
          !*************************************************************
          !*************************************************************

          SUBROUTINE Check_File(filename, FileUnit)

          IMPLICIT NONE

          CHARACTER*150 filename
          INTEGER FileUnit
          LOGICAL FileFlag

          INQUIRE(FILE=TRIM(filename),EXIST=FileFlag)

          IF(FileFlag) THEN
            OPEN(FileUnit,file=filename)
            !WRITE(*,*),' Reading in: ', TRIM(filename)
          ELSE
            WRITE(*,*) ' ERROR, input file NOT found: ', TRIM(filename)
            STOP
          ENDIF

          END SUBROUTINE Check_File


          !*************************************************************
          !*************************************************************
          ! Check the p(x,y) is on the right side (side=1), 
          ! left side (side=-1) or colinear (side=0) of 
          ! line (x1,y1),(x2,y2)
          !*************************************************************
          !*************************************************************

          SUBROUTINE Check_Side(x1,y1,x2,y2,px,py,side)

          IMPLICIT NONE

          REAL x1, y1, x2, y2, px, py
          REAL dx1, dx2, dy1, dy2, o
          INTEGER side

          dx1 = x2 - x1
          dy1 = y2 - y1
          dx2 = px - x1
          dy2 = py - y1
          o = dx1*dy2 - dy1*dx2

          IF ( o == 0.0 ) THEN
            side =  0
            PRINT*, "Colinear !!: ", x1,y1,x2,y2,px,py
            !STOP
          ENDIF

          IF ( o  > 0.0 ) side = -1
          IF ( o  < 0.0 ) side =  1

          END SUBROUTINE Check_Side

          !*************************************************************
          !*************************************************************
          ! Sort 4 corners in clockwise order
          !*************************************************************
          !*************************************************************

          SUBROUTINE Clockwise_Sort(x,y,order)

          IMPLICIT NONE

          REAL x(4), y(4)
          INTEGER order(4)
          INTEGER side3, side4, s4

          ! 1st point as the start point
          order(1) = 1

          CALL Check_Side( x(1), y(1), x(2), y(2), x(3), y(3), side3)
          CALL Check_Side( x(1), y(1), x(2), y(2), x(4), y(4), side4)

          IF ( side3 > 0 .AND. side4 > 0 ) THEN
            CALL Check_Side( x(1), y(1), x(3), y(3), x(4), y(4), s4)
            IF ( s4 > 0 ) order(2:4) = (/ 2, 3, 4/)
            IF ( s4 < 0 ) order(2:4) = (/ 2, 4, 3/)
          ELSEIF ( side3 < 0 .AND. side4 < 0 ) THEN
            CALL Check_Side( x(1), y(1), x(3), y(3), x(4), y(4), s4)
            IF ( s4 > 0 ) order(2:4) = (/ 3, 4, 2 /)
            IF ( s4 < 0 ) order(2:4) = (/ 4, 3, 2 /)
          ELSE
            CALL Check_Side( x(1), y(1), x(3), y(3), x(4), y(4), s4)
            IF ( s4 > 0 ) order(2:4) = (/ 3, 2, 4 /)
            IF ( s4 < 0 ) order(2:4) = (/ 4, 2, 3 /)
          ENDIF

          END SUBROUTINE

          !*************************************************************
          !*************************************************************
          ! Cal area based on 4 corners
          !*************************************************************
          !*************************************************************

          SUBROUTINE Cal_Quard_Area(x, y, A)

          IMPLICIT NONE

          REAL x(4), y(4), A

          A = ABS(x(1)*y(2)-y(1)*x(2) + x(2)*y(3)-y(2)*x(3) +    &
                  x(3)*y(4)-y(3)*x(4) + x(4)*y(1)-y(4)*x(1))/2

          END SUBROUTINE       

          !*************************************************************
          !*************************************************************
          ! Lambert conformal conic (LCC)  Projection, taken from CALMET
          !*************************************************************
          !*************************************************************

          SUBROUTINE mapg2l(alat,alon,xdist,ydist)
          ! -----------------------------------------------------------
          IMPLICIT NONE
          REAL rlat,rlon,tlat1,tlat2,alat,alon,xdist,ydist
          REAL pi4,radcon,rearth
          REAL a1,a2,a3,a4,a5,cc,psi,rho,rho1,theta,thetab 

          ! --- Set constants: PI4 = pi/4., RADCON=pi/180.
          data pi4/0.78539816/, radcon/0.017453293/
          data rearth/6371.0/
          
          ! --- Set orign point and two standard parallels
          ! --- For CONUS, need to be changed for other regions
          data rlat/39.0/, rlon/-96.0/
          data tlat1/33.0/, tlat2/45.0/ 

          ! --- Compute constants depending on standard parallels and
          ! --- reference coordinates
          a1 = cos(tlat1*radcon)/cos(tlat2*radcon)
          a2 = tan(pi4 - 0.5*(radcon*tlat1))
          a3 = tan(pi4 - 0.5*(radcon*tlat2))
          a5 = tan(pi4 - 0.5*(radcon*rlat))

          ! --- Compute the cone constant (cc), (K in other people's notation)
          cc = alog(a1)/alog(a2/a3)

          ! --- Scaling function
          psi = rearth*cos(tlat1*radcon)/(cc*a2**cc)
          rho1 = psi*a5**cc

          ! --- Start estimate of (alat,alon) to (x,y)
          ! --- Polar angle
          a4 = tan(pi4 - (radcon*alat)/2.0)
          theta = alon - rlon

          ! reset theta to range -180 to 180 degrees - bdf
          if (theta.lt.-180.0) theta = theta + 360.0
          if (theta.gt.180.0) theta = theta - 360.0
          thetab = theta*cc*radcon

          ! --- Polar radii (origin,latitude(alat))
          rho = psi*a4**cc

          ! --- Cartesian distances for a round earth in meters (S=1)
          xdist = rho*sin(thetab)
          ydist = rho1 - rho*cos(thetab)

          END SUBROUTINE

END MODULE tools_m
