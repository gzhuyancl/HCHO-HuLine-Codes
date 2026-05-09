# This script is to read daily satellite files. 
# This script generates daily L2 RData.

t1<-proc.time()

#-------------------------------------------------------------------------------------------
# Load libraies
#-------------------------------------------------------------------------------------------

library(doParallel)
library(rhdf5)
library(lubridate)

#-------------------------------------------------------------------------------------------
# Set parameters
#-------------------------------------------------------------------------------------------

#---> Set the woeking directory
workingdir             <- "/home/data/"
setwd(workingdir)

#---> Set date range of interest
Date_limit             <- c("2023-08-01", "2023-08-31")

#---> allocate the threads for this job
cl <- makeCluster(6) 
registerDoParallel(cl)

#---> Set TROPOMI L2 file and daily RData file directory
L2_he5_folder           <- "/home/data/OMI_data/"
L2_RData_folder        <- "data/L2_RData/"
L2_merge_folder        <- "data/L2_merge/"
L3_daily_RData_folder  <- "data/L3_daily_RData/"

#---> Set oversampling code dir
Cakecut_folder         <- "cakecut_src/"

#---> Set the limits for satellite pixels, used for data quality control
VCD_limit              <- c( -1e15 , 1.0e17 )  # VCD range
CF_limit               <- c(  0.0  , 0.3    )  # Cloud faction range
SZA_limit              <- c(  0.0  , 60.0   )  # SZA fange

# Deal with OMI row anomalies
Rows_valid             <- c(seq(1,20),seq(55,60))

#---> Set the max data points for a day, used in defining the arraies
MAX_points             <- 1e6

#---> Get a list of L2 files
L2_file_list           <- list.files(L2_he5_folder)
L2_file_date           <- paste0(substr(L2_file_list,20,23),substr(L2_file_list,25,28))
Date_temp              <- seq(as.Date(Date_limit[1]),as.Date(Date_limit[2]),by="days")
Date_list              <- paste0(substr(Date_temp,1,4),substr(Date_temp,6,7),substr(Date_temp,9,10))

#-------------------------------------------------------------------------------------------
# Start computing
#-------------------------------------------------------------------------------------------

#---> Set the Dataloop function for Multithreaded (parallel) computing
Dataloop <- function(){
  
      #---> Get file index
      L2_file_day_list     <- grep(Date_list[iday], L2_file_date)
      
      #---> Is this date found in the L2 folder
      if( length(L2_file_day_list) > 0 ){
    
        print("")    
        print("============================================")
        print(paste(" Process :", Date_list[iday]))
        print("============================================")
        
        print(" * Reading satellite files")
     
        #---> Define data arraies
        Pixel_count        <- 0
        SATE_Time          <- array(NA,dim=c(MAX_points,1))
        SATE_LAT           <- array(NA,dim=c(MAX_points,5))
        SATE_LON           <- array(NA,dim=c(MAX_points,5))
        SATE_VCD           <- array(NA,dim=c(MAX_points))
        SATE_VCDError      <- array(NA,dim=c(MAX_points))
        SATE_AMF           <- array(NA,dim=c(MAX_points))
        SATE_SZA           <- array(NA,dim=c(MAX_points))
        SATE_VZA           <- array(NA,dim=c(MAX_points))
        SATE_CloudFraction <- array(NA,dim=c(MAX_points))
        SATE_CloudPressure <- array(NA,dim=c(MAX_points))
        SATE_CloudHeight   <- array(NA,dim=c(MAX_points))
        
        #---> Now loop L2 files
        for(ifile in 1:length(L2_file_day_list)){
          
          #---> Get the file name and print
          L2_file          <- paste(L2_he5_folder, L2_file_list[L2_file_day_list[ifile]], sep="")
          print(paste("   - Orbit", substr(L2_file_list[L2_file_day_list[ifile]],35,40)))
          
          #---> Read the file
          VCD              <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Data Fields/ReferenceSectorCorrectedVerticalColumn")                    # molec. cm-2
          VCDError         <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Data Fields/ColumnUncertainty")         # molec. cm-2
          CloudFraction    <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Data Fields/AMFCloudFraction")          # -
          CloudPressure    <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Data Fields/AMFCloudPressure")          # -
          SZA              <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Geolocation Fields/SolarZenithAngle")
          VZA              <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Geolocation Fields/ViewingZenithAngle")
          LATCenter        <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Geolocation Fields/Latitude")
          LATConrner       <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Data Fields/PixelCornerLatitudes")
          LONCenter        <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Geolocation Fields/Longitude")
          LONConrner       <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Data Fields/PixelCornerLongitudes")
          QAValue          <- h5read(L2_file,"HDFEOS/SWATHS/OMI Total Column Amount HCHO/Data Fields/MainDataQualityFlag")
          TimeUTC          <- h5read(L2_file,"/HDFEOS/SWATHS/OMI Total Column Amount HCHO/Geolocation Fields/TimeUTC") 
          h5closeAll()
          
          #TImeUTC convertion
          CTimeUTC <- array(NA,dim=c(1,ncol(TimeUTC)))
          CTimeUTC[1,1:ncol(TimeUTC)] <- paste0(TimeUTC[1,],'-',TimeUTC[2,],'-',TimeUTC[3,],'-',TimeUTC[4,],'-',TimeUTC[5,],'-',TimeUTC[6,])
          CTimeUTC <- as.vector(CTimeUTC[1, ])
          CTimeUTC <- as.character(ymd_hms(CTimeUTC))
          
          #---> Select valid pixels based on the limits set previously
          NPixels          <- dim(VCD)[1] #nTimes ~1650
          NScans           <- dim(VCD)[2] #nXtrack ~30-60
          for(ipixel in 1:NPixels){
            # Row falls within the valid range
            if( !is.na(match(ipixel,Rows_valid)) ){
              for(iscan in 1:NScans){
                if( QAValue[ipixel, iscan]        == 0            && 
                    VCD[ipixel, iscan]            >= VCD_limit[1] && 
                    VCD[ipixel, iscan]            <= VCD_limit[2] &&
                    CloudFraction[ipixel, iscan]  >= CF_limit[1]  && 
                    CloudFraction[ipixel, iscan]  <= CF_limit[2]  && 
                    SZA[ipixel, iscan]            >= SZA_limit[1] && 
                    SZA[ipixel, iscan]            <= SZA_limit[2] ){
                  
                  #---> Now get a valid pixel, get data fields
                  Pixel_count                     <- Pixel_count + 1
                  SATE_Time[Pixel_count,]         <- c(CTimeUTC[iscan])
                  SATE_LAT[Pixel_count,]          <- c(LATCenter[ipixel, iscan], LATConrner[ipixel, iscan:(iscan+1)], 
                                                       LATConrner[ipixel+1, iscan:(iscan+1)] )
                  SATE_LON[Pixel_count,]          <- c(LONCenter[ipixel, iscan], LONConrner[ipixel, iscan:(iscan+1)],
                                                       LONConrner[ipixel+1, iscan:(iscan+1)] )
                  SATE_VCD[Pixel_count]           <- VCD[ipixel, iscan]
                  SATE_VCDError[Pixel_count]      <- VCDError[ipixel, iscan]
                  # SATE_AMF[Pixel_count]           <- AMF[ipixel, iscan, 1]
                  SATE_SZA[Pixel_count]           <- SZA[ipixel, iscan]              
                  SATE_VZA[Pixel_count]           <- VZA[ipixel, iscan]    
                  SATE_CloudFraction[Pixel_count] <- CloudFraction[ipixel, iscan]    
                  # SATE_CloudPressure[Pixel_count] <- CloudPressure[ipixel, iscan, 1]    
                  # SATE_CloudHeight[Pixel_count]   <- CloudHeight[ipixel, iscan, 1]    
                    
                } # Valide pixel	
              }   #	Loop scan lines (1-3500)
            }     # # Row falls within the valid range
          }     # Loop rows (1-450)
        }       # Loop L2 file files
      }         # Date found in the L2 folder
    
      #---> Resize the arraies, to save space
      SATE_Time            <- SATE_Time[1:Pixel_count,]
      SATE_LAT             <- SATE_LAT[1:Pixel_count,]
      SATE_LON             <- SATE_LON[1:Pixel_count,]
      SATE_VCD             <- SATE_VCD[1:Pixel_count]
      SATE_VCDError        <- SATE_VCDError[1:Pixel_count]
      # SATE_AMF             <- SATE_AMF[1:Pixel_count]
      SATE_SZA             <- SATE_SZA[1:Pixel_count]
      SATE_VZA             <- SATE_VZA[1:Pixel_count]
      SATE_CloudFraction   <- SATE_CloudFraction[1:Pixel_count]
      # SATE_CloudPressure   <- SATE_CloudPressure[1:Pixel_count]
      # SATE_CloudHeight     <- SATE_CloudHeight[1:Pixel_count]
      
      #---> Save data into the RData file
      print(" * Saving daily RData")
      RData_name           <- paste(L2_RData_folder,"OMI_HCHO_",Date_list[iday],".RData",sep="")
      save(file=RData_name, Pixel_count, SATE_Time, SATE_LAT, SATE_LON, SATE_VCD,
           SATE_VCDError, SATE_SZA, SATE_VZA, SATE_CloudFraction)
      
} # End of the daily Loop

#---> Use foreach for parrallel computing
foreach(iday = 1:length(Date_list), .combine='rbind', .packages= c('rhdf5','gdata','RNetCDF','lubridate')) %dopar% {
  Dataloop()
}

stopCluster(cl)

#--> Give a time count to the process
t2<-proc.time()
t<-t2-t1
print(paste0("runing time: ",t[3][[1]]/60,' min'))