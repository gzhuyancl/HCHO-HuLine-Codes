# Oversampling Workflow

This folder contains the oversampling workflow for generating gridded HCHO products from satellite observations. The workflow combines a Fortran oversampling kernel with R preparation scripts and Python utilities for output conversion and use.

```text
Level-2 satellite observations -> daily gridded outputs -> analysis-ready netCDF files
```

## Folder Guide

For the basic run sequence, see `QUICK_START.md`.

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

R interface scripts for the oversampling workflow.

```text
1he5toL2_OMI_demo.R        Read satellite files and generate daily L2 RData
2L2RDATAtoL3_OMI_demo.R    Generate daily merged L3 RData files
3Plot_OMI_demo.R           Average columns and plot results
```

### `code_application/`

Python utilities for converting and using the oversampling outputs.

```text
RData_convert_netCDF.py    Convert RData files to netCDF format
netCDF_use_demo.py         Read and inspect oversampling results in netCDF format
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
