# This script is to prepare merge files, 
# and proceed daily oversampiling/regridding. 
# This script generates daily merge, and L3 RData files, 
# and compress daily merge files to save space.

t1<-proc.time()

#-------------------------------------------------------------------------------------------
# Load libraies
#-------------------------------------------------------------------------------------------

library(doParallel)
library(gdata)

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
L2_he5_folder          <- "/home/data/OMI_data/"
L2_RData_folder        <- "data/L2_RData/"
L2_merge_folder        <- "data/L2_merge/"
L3_daily_RData_folder  <- "data/L3_daily_RData/"

#---> Set oversampling code dir
Cakecut_folder         <- "cakecut_src/"

#---> Get file index and date 
L2_file_list           <- list.files(L2_he5_folder)
L2_file_date           <- paste0(substr(L2_file_list,20,23),substr(L2_file_list,25,28))
Date_temp              <- seq(as.Date(Date_limit[1]),as.Date(Date_limit[2]),by="days")
Date_list              <- paste(substr(Date_temp,1,4),substr(Date_temp,6,7),substr(Date_temp,9,10),sep="")

#-------------------------------------------------------------------------------------------
# Start computing
#-------------------------------------------------------------------------------------------

#---> Set the Dataloop function for Multithreaded (parallel) computing
Dataloop <- function(){
      
      #---> Read the L2 RData that has been generated.
      RData_name           <- paste(L2_RData_folder,"OMI_HCHO_",Date_list[iday],".RData",sep="")
      RData                <- load(RData_name)
      #---> Save the data to merge file, used for daily oversampling
      #     This step takes a while to finish
      print(" * Saving daily merge file")
      Data_temp            <- data.frame(SATE_LAT, SATE_LON, SATE_VCD, SATE_VCDError)
      #---> delete the pixels (rows) with NA 
      Data_temp <- Data_temp[complete.cases(Data_temp),]
      
      Merge_file           <- paste(L2_merge_folder,"OMI_merge_daily_",Date_list[iday],sep="")
      write.fwf(Data_temp, Merge_file, width=rep(15,12), colnames=FALSE, scientific=TRUE)
      
      #---> Make sure there is no NA, NaN, Na, or na in the daily merge file
      print(" * Replacing NA values")
      system(sprintf("sed -i 's/NaN/-9999/g' %s", Merge_file))
      system(sprintf("sed -i 's/NA/-9999/g' %s", Merge_file))
      system(sprintf("sed -i 's/na/-9999/g' %s", Merge_file))
      system(sprintf("sed -i 's/Na/-9999/g' %s", Merge_file))
      
      #---> Compress the daily merge file to save space
      print(" * Compressing daily merge file")
      system(sprintf("gzip %s",Merge_file))
      
      #---> Prepare daily oversampling inputs
      print(" * Proceeding daily oversampling")
      
      #---> Make a copy of the cakecut_src folder, use it as the temp oversampling folder
      cakecut_tmp_folder <- paste("tmp/cakecut_",Date_list[iday],sep="")
      system(sprintf("cp -r %s %s",Cakecut_folder,cakecut_tmp_folder))
      
      #---> Copy the daily merge file to the temp folder
      system(sprintf("cp %s %s",paste(Merge_file,".gz",sep=""),paste(cakecut_tmp_folder,"/Merge_temp.gz",sep="")))
      
      #---> Decompress the gz file
      system(sprintf("gzip -d %s",paste(cakecut_tmp_folder,"/Merge_temp.gz",sep="")))
    
      #---> Do daily oversamling in the temp folder
      setwd(cakecut_tmp_folder)
      system(sprintf("csh run_oversampling.sh"))
      
      #---> Save oversampling results as RData
      print(" * Saving daily L3 RData file")
      data_raw                 <- read.table("L3_Daily_temp",header=F)
      save(data_raw,file="L3_Daily_temp.RData")
      
      #---> Reset the wd
      setwd(workingdir)
      
      #---> Move dialy L3 output
      system(sprintf("mv %s %s",paste(cakecut_tmp_folder,"/L3_Daily_temp.RData",sep=""),
                     paste(L3_daily_RData_folder,"/OMI_HCHO_Daily_L3_",Date_list[iday],".RData",sep="")))
      
      #---> Start cleaning
      print(" * Cleaning daily temp files and free the memory")
      
      #---> Remove daily temp cakecut folder
      system(sprintf("rm -rf %s ",cakecut_tmp_folder))
      
      #---> Clean memory
      rm(Pixel_count, SATE_Time, SATE_LAT, SATE_LON, SATE_VCD, SATE_VCDError, SATE_AMF, SATE_SZA, 
         SATE_VZA, SATE_CloudFraction, SATE_CloudPressure, SATE_CloudHeight, Data_temp)
      gc(full = TRUE)  
      
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