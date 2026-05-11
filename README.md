# HCHO VCD Prediction and Oversampling Workflow

This repository contains the project workflow for annual tropospheric formaldehyde (HCHO) vertical column density (VCD) prediction and satellite-pixel oversampling.

## Repository Structure

```text
RF/
  RF1.py
  RF2.py
  README.md

Oversampling/
  README.md
  QUICK_START.md
  cakecut_src/
  code_oversampling/
  code_application/
```

## RF Prediction Codes

The `RF/` folder contains two Random Forest prediction scripts:

- `RF/RF1.py`: RF1, independent grid-cell time-series prediction.
- `RF/RF2.py`: RF2, line-based spatiotemporal prediction.

The default target years are:

```text
2005-2022 -> 2023
2005-2023 -> 2024
```

See `RF/README.md` for input formats, run commands, outputs, and method details.

## Oversampling Codes

The `Oversampling/` folder contains the oversampling workflow used in this project. It includes the Fortran oversampling kernel, R scripts for preparing and gridding satellite observations, and Python utilities for converting and reading gridded outputs.

```text
Level-2 satellite observations -> daily gridded HCHO products -> netCDF outputs
```

See `Oversampling/README.md` for the detailed file guide and system requirements.
