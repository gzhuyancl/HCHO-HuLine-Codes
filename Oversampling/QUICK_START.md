# Quick Start: Oversampling

This guide shows the basic command sequence for running the oversampling workflow after the local paths and processing parameters have been configured.

## Prepare Input Files

Place the Level-2 satellite input files in the folder configured by `L2_he5_folder` in the R scripts. The default script path is:

```text
/home/data/OMI_data/
```

Update this path, the working directory, and the date range before running the scripts:

```r
workingdir <- "/home/data/"
Date_limit <- c("2023-08-01", "2023-08-31")
L2_he5_folder <- "/home/data/OMI_data/"
```

## Prepare Working Folders

Run the workflow from the configured working directory. The following folders should be available under the working directory:

```text
cakecut_src/
tmp/
grid_data/
figs/
data/
  L2_RData/
  L2_merge/
  L3_daily_RData/
```

Install the required R libraries and make sure the Fortran oversampling kernel can be compiled and executed in the local Linux environment.

## Run The Workflow

Generate daily Level-2 RData files:

```bash
Rscript 1he5toL2_OMI_demo.R
```

If an input file is faulty, the script may stop with a message similar to `missing value where TRUE/FALSE needed`. Remove or repair the faulty input file and rerun the command.

Generate daily merged Level-3 files:

```bash
Rscript 2L2RDATAtoL3_OMI_demo.R
```

Before this step, set the target grid resolution in `cakecut_src/run_oversampling.sh`:

```sh
set_Res=0.1
```

Use the resolution required by the current run.

Generate averaged gridded data and figures:

```bash
Rscript 3Plot_OMI_demo.R
```

After this step, the workflow writes oversampled grid data to `grid_data/` and spatial figures to `figs/`.
