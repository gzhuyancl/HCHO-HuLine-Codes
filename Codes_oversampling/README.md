# ScienceDB Oversampling Codes

This folder contains oversampling example codes downloaded from the ScienceDB dataset:

```text
Global OMI HCHO Level-3 oversampling dataset
DOI: https://doi.org/10.57760/sciencedb.29626
Source: https://www.scidb.cn/detail?dataSetId=a3d2f13ae6064ecb809430fb1ef51f6f
License: CC BY 4.0
```

## Folder Guide

### `cakecut_src/`

Core oversampling kernel files.

```text
cakecut_m.f90                         Source code for horizontal and vertical cutting
cakecut_m.mod                         Module file for cakecut_m.f90
Oversampling_Daily_Regridding.f90     Source code for satellite pixel oversampling and uncertainty propagation
Oversampling_Daily_Regridding.x       Precompiled Linux binary for Oversampling_Daily_Regridding.f90
run_oversampling.sh                   Shell script for adjusting oversampling execution parameters
tools_m.f90                           Source code for checking input parameters and pixel geographic information
tools_m.mod                           Module file for tools_m.f90
```

### `code_oversampling/`

R interface and demonstration scripts for the oversampling workflow.

```text
1he5toL2_OMI_demo.R        Read satellite files and generate daily L2 RData
2L2RDATAtoL3_OMI_demo.R    Generate daily merged L3 RData files
3Plot_OMI_demo.R           Average columns and plot results
```

### `code_application/`

Python examples for processing the oversampling dataset.

```text
RData_convert_netCDF.py    Convert RData files to netCDF format
netCDF_use_demo.py         Demonstrate use of the oversampling dataset in netCDF format
```

## System Requirements

Software environment:

```text
Fortran 90
R 4.1.2
Python 3.0 or later
```

Hardware requirements:

```text
CPU: 2 GHz or higher
Memory: 1 GB or more
Disk: at least 5 GB of available storage
```
