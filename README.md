# HCHO VCD Prediction and Oversampling Codes

This repository contains code for annual tropospheric formaldehyde (HCHO) vertical column density (VCD) prediction and oversampling examples.

## Repository Structure

```text
RF/
  RF1.py
  RF2.py
  README.md

Oversampling/
  README.md
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

The `Oversampling/` folder contains oversampling example codes downloaded from the ScienceDB dataset:

```text
Global OMI HCHO Level-3 oversampling dataset
DOI: https://doi.org/10.57760/sciencedb.29626
Source: https://www.scidb.cn/detail?dataSetId=a3d2f13ae6064ecb809430fb1ef51f6f
License: CC BY 4.0
```

See `Oversampling/README.md` for the detailed file guide and system requirements.
