# This script is to get averaged colums from a perid of time,
# and plot the results.

t1<-proc.time()

#-------------------------------------------------------------------------------------------
# Load libraies
#-------------------------------------------------------------------------------------------

library(fields);library(maps)

#-------------------------------------------------------------------------------------------
# Set parameters
#-------------------------------------------------------------------------------------------

#---> Set wd
workingdir             <- "/home/data/"
setwd(workingdir)

#---> Set TROPOMI daily L3 file directory
L3_daily_RData_folder  <- "data/L3_daily_RData/"

#---> Set date range of interest
Date_limit             <- c("2023-08-01", "2023-08-31")

#---> Set the min pixels needed for a valid grid
pixel_limit            <- 5

#---> Get data domain and grids
#     The parameters HAVE to be the same as those in cakecut scripts
res                    <- 0.05
region                 <- c(-200,200,-100,100)

#---> Define the region to plot
plot_region            <- c(-180,180,-90,90)   # Global
region_name            <- "Global"

#---> Limits for plotting 
zmin                   <- 0  # [10^15 molec. cm-2]
zmax                   <- 20 # [10^15 molec. cm-2]

UNCmin                 <- 0
UNCmax                 <- 30

UNC2Avermin            <- 0
UNC2Avermax            <- 0.5

#-------------------------------------------------------------------------------------------
# Start computing
#-------------------------------------------------------------------------------------------

#---> Make list of valid daily files
L3_list                <- list.files(L3_daily_RData_folder)
L3_date                <- substr(L3_list,19,26)
Date_temp              <- seq(as.Date(Date_limit[1]),as.Date(Date_limit[2]),by="days")
Date_list              <- paste(substr(Date_temp,1,4),substr(Date_temp,6,7),substr(Date_temp,9,10),sep="")

#---> Define the grids
NRows                  <- (region[4]-region[3])/res
NCols                  <- (region[2]-region[1])/res
Lat_common             <- seq((region[3]+0.5*res),(region[3]+0.5*res)+(NRows-1)*res,by=res)
Lon_common             <- seq((region[1]+0.5*res),(region[1]+0.5*res)+(NCols-1)*res,by=res)

#---> Define the arraeis
SumAbove_grids         <- array(0,dim=c(NCols, NRows))
SumBelow_grids         <- array(0,dim=c(NCols, NRows))
SumAbove_UNC_grids     <- array(0,dim=c(NCols, NRows))
SumBelow_UNC_grids     <- array(0,dim=c(NCols, NRows))
N_grids                <- array(0,dim=c(NCols, NRows))

#---> Loop dates of interest
for(iday in 1:length(Date_list)){
  
  #---> Get file index
  L3_file_index        <- grep(Date_list[iday], L3_date)
  
  #---> Is this date found in the L3 daily RData folder
  if( length(L3_file_index) > 0 ){
    
    print(paste(" Process :", Date_list[iday]))

    # Get the data
    L3_file_ori        <- paste(L3_daily_RData_folder,L3_list[L3_file_index],sep="")
    L3_file_tmp        <- paste("tmp/",L3_list[L3_file_index],sep="")
    # Make a copy to temp
    system(sprintf("cp %s %s",L3_file_ori,L3_file_tmp))
    # Now load the daily L3 RData file
    load(L3_file_tmp)
    Nlines             <- dim(data_raw)[1]
    row_raw            <- data_raw[,1]
    col_raw            <- data_raw[,2]
    Above_raw          <- data_raw[,3]
    Below_raw          <- data_raw[,4]
    Above_UNC_raw      <- data_raw[,6]
    Below_UNC_raw      <- data_raw[,7]
    N_raw              <- data_raw[,9]
    for(i in 1:Nlines){
      SumAbove_grids[col_raw[i],row_raw[i]] <- SumAbove_grids[col_raw[i],row_raw[i]] + Above_raw[i]
      SumBelow_grids[col_raw[i],row_raw[i]] <- SumBelow_grids[col_raw[i],row_raw[i]] + Below_raw[i]
      SumAbove_UNC_grids[col_raw[i],row_raw[i]] <- SumAbove_UNC_grids[col_raw[i],row_raw[i]] + Above_UNC_raw[i]
      SumBelow_UNC_grids[col_raw[i],row_raw[i]] <- SumBelow_UNC_grids[col_raw[i],row_raw[i]] + Below_UNC_raw[i]
      N_grids[col_raw[i],row_raw[i]]        <- N_grids[col_raw[i],row_raw[i]]        + N_raw[i]
    } # Loop daily grids
    # Clean
    system(sprintf("rm %s ",L3_file_tmp))
  }else{
    print(paste(" NO L3 daily RData file for :", Date_list[iday]))
  }   # Check daily L3 RData file
}     # Loop days of interest

#---> Only plot grids with more than pixel_limit crossed pixels
for(col in 1:NCols){
  row_list                     <- which(N_grids[col,]<=pixel_limit)
  SumAbove_grids[col,row_list] <- NA
  SumBelow_grids[col,row_list] <- NA
  SumAbove_UNC_grids[col,row_list] <- NA
  SumBelow_UNC_grids[col,row_list] <- NA
}
Average_grids                  <- SumAbove_grids/SumBelow_grids
Average_UNC_grids              <- sqrt(SumAbove_UNC_grids/(SumBelow_UNC_grids^2))
UNC_to_Average                 <- Average_UNC_grids/Average_grids

# #---> Only plot grids with less than threshold crossed pixels
# for(col in 1:NCols){
#   UNC2Average_list                     <- which(UNC_to_Average[col,]>0.25 | UNC_to_Average[col,]<0)
#   Average_grids[col,UNC2Average_list] <- NA
#   Average_UNC_grids[col,UNC2Average_list] <- NA
#   UNC_to_Average[col,UNC2Average_list] <- NA
# }

save(Average_grids, Average_UNC_grids, UNC_to_Average,file=paste("./grid_data/OMI_HCHO_",region_name,"_",min(Date_temp),"_",
                               max(Date_temp),"_Res_",as.character(res),"_PL_",as.character(pixel_limit),".RData",sep=""))

#-------------------------------------------------------------------------------------------
# Start plotting
#-------------------------------------------------------------------------------------------

Row_down               <- which(abs(Lat_common-plot_region[3])==min(abs(Lat_common-plot_region[3])))[1]
Row_up                 <- which(abs(Lat_common-plot_region[4])==min(abs(Lat_common-plot_region[4])))[1]
Col_left               <- which(abs(Lon_common-plot_region[1])==min(abs(Lon_common-plot_region[1])))[1]
Col_right              <- which(abs(Lon_common-plot_region[2])==min(abs(Lon_common-plot_region[2])))[1]

#---> plot average
plotname	       <- paste("figs/OMI_HCHO_",min(Date_temp),"_",
                                max(Date_temp),"_Res_",as.character(res),"_PL_",as.character(pixel_limit),"_zmax_", as.character(zmax),
                                "_UNCmax_", as.character(UNCmax), "_UNC2Avermax_", as.character(UNC2Avermax), ".png",sep="")

png(plotname, width=8.5, height=6, units="in", res=400)
par(mar=c(4.5,3,2,1))# Bottom, left, top, right
image.plot(Lon_common[Col_left: Col_right], Lat_common[Row_down: Row_up],
           Average_grids[Col_left: Col_right, Row_down: Row_up]/1e15,zlim=c(zmin,zmax),
           horizontal=T,useRaster=T,
           legend.shrink=0.75,axis.args = list(cex.axis = 1.25),legend.width=1,legend.mar=2,
           legend.args=list(text=expression(paste("HCHO column density [",10^15, " molecules ",cm^-2,"]")),cex=1.25),
           xlab='',ylab='',midpoint=T, axes=F, ann=F
)
title(xlab="",cex.lab=1.25,font.lab=2)
axis(1,at=pretty(Lon_common[Col_left:Col_right]),tck=-0.015,lwd=2,cex.axis=1.25,font=1)
title(ylab="",cex.lab=1.25,font.lab=2)
axis(2,at=pretty(Lat_common[Row_down:Row_up]),tck=-0.015,lwd=2,cex.axis=1.25,font=1,las=1)
title(main=paste("OMI_HCHO_",min(Date_temp),"_",max(Date_temp),"_Res_",as.character(res),sep=""),cex.main=1,font.main=2)
map('world',add=T,lwd=0.75,col="black")
box(lwd=2)
dev.off()

#---> plot average uncertainty
plotname	       <- paste("figs/OMI_HCHO_uncertainty_",min(Date_temp),"_",max(Date_temp),"_Res_",as.character(res),"_PL_",
                         as.character(pixel_limit),"_zmax_", as.character(zmax),"_UNCmax_", as.character(UNCmax),"_UNC2Avermax_", 
                         as.character(UNC2Avermax),".png",sep="")

png(plotname, width=8.5, height=6, units="in", res=400)
par(mar=c(4.5,3,2,1))# Bottom, left, top, right
image.plot(Lon_common[Col_left: Col_right], Lat_common[Row_down: Row_up],
           Average_UNC_grids[Col_left: Col_right, Row_down: Row_up]/1e14,zlim=c(UNCmin,UNCmax),
           horizontal=T,useRaster=T,
           legend.shrink=0.75,axis.args = list(cex.axis = 1.25),legend.width=1,legend.mar=2,
           legend.args=list(text=expression(paste("Uncertainty of HCHO column density [",10^14, " molecules ",cm^-2,"]")),cex=1.25),
           xlab='',ylab='',midpoint=T, axes=F, ann=F
)
title(xlab="",cex.lab=1.25,font.lab=2)
axis(1,at=pretty(Lon_common[Col_left:Col_right]),tck=-0.015,lwd=2,cex.axis=1.25,font=1)
title(ylab="",cex.lab=1.25,font.lab=2)
axis(2,at=pretty(Lat_common[Row_down:Row_up]),tck=-0.015,lwd=2,cex.axis=1.25,font=1,las=1)
title(main=paste("OMI_HCHO_uncertainty_",min(Date_temp),"_",max(Date_temp),"_Res_",as.character(res),sep=""),cex.main=1,font.main=2)
map('world',add=T,lwd=0.75,col="black")
box(lwd=2)
dev.off()

#---> plot the ratio of uncertainty to average
plotname	       <- paste("figs/OMI_uncertainty2average_",min(Date_temp),"_",max(Date_temp),"_Res_",as.character(res),"_PL_",
                         as.character(pixel_limit),"_zmax_", as.character(zmax),"_UNCmax_", as.character(UNCmax),"_UNC2Avermax_", 
                         as.character(UNC2Avermax),".png",sep="")

png(plotname, width=8.5, height=6, units="in", res=400)
par(mar=c(4.5,3,2,1))# Bottom, left, top, right
image.plot(Lon_common[Col_left: Col_right], Lat_common[Row_down: Row_up],
           UNC_to_Average[Col_left: Col_right, Row_down: Row_up],zlim=c(UNC2Avermin,UNC2Avermax),
           horizontal=T,useRaster=T,
           legend.shrink=0.75,axis.args = list(cex.axis = 1.25),legend.width=1,legend.mar=2,
           legend.args=list(text=expression(paste("Ratio of uncertainty to average VCD")),cex=1.25),
           xlab='',ylab='',midpoint=T, axes=F, ann=F
)
title(xlab="",cex.lab=1.25,font.lab=2)
axis(1,at=pretty(Lon_common[Col_left:Col_right]),tck=-0.015,lwd=2,cex.axis=1.25,font=1)
title(ylab="",cex.lab=1.25,font.lab=2)
axis(2,at=pretty(Lat_common[Row_down:Row_up]),tck=-0.015,lwd=2,cex.axis=1.25,font=1,las=1)
title(main=paste("OMI_HCHO_uncertainty2average_",min(Date_temp),"_",max(Date_temp),"_Res_",as.character(res),sep=""),cex.main=1,font.main=2)
map('world',add=T,lwd=0.75,col="black")
box(lwd=2)
dev.off()

#--> Give a time count to the process
t2<-proc.time()
t<-t2-t1
print(paste0("runing time: ",t[3][[1]]/60,' min'))