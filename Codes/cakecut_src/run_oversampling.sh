#!/bin/csh -f

# Compile the fortran code
gfortran -o Oversampling_Daily_Regridding.x cakecut_m.f90 tools_m.f90 Oversampling_Daily_Regridding.f90

#--------------------------------------
# GLOBAL DAILY OVERSAMPILNG
#--------------------------------------
set Lat_low         = -100
set Lat_up          = 100
set Lon_left        = -200
set Lon_right       = 200
set Res             = 0.05
./Oversampling_Daily_Regridding.x<<EOF
$Lat_low
$Lat_up
$Lon_left
$Lon_right
$Res
EOF
quit:

exit
