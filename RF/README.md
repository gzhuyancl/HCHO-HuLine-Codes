# RF Prediction Codes

This folder contains two Random Forest scripts for annual tropospheric formaldehyde (HCHO) vertical column density (VCD) prediction.

- `RF1.py`: RF1, independent grid-cell time-series prediction.
- `RF2.py`: RF2, line-based spatiotemporal prediction.

The default target years are:

```text
2005-2022 -> 2023
2005-2023 -> 2024
```

No local data paths are hard-coded. Users provide input and output paths when running the scripts.

## Python Dependencies

```bash
pip install numpy pandas scikit-learn tqdm joblib
```

## RF1

Use `RF1.py` when each CSV row contains one yearly time series.

Expected format:

```text
meta1,meta2,meta3,meta4,meta5,meta6,2005,2006,...,2022,2023,2024
```

By default, the first 6 columns are treated as metadata, and yearly value columns start from `2005`.

Run from the repository root:

```bash
python RF/RF1.py --input-dir "path/to/input_csv_folder" --output-dir "path/to/output_folder"
```

Run one target year only:

```bash
python RF/RF1.py --input-dir "path/to/input_csv_folder" --output-dir "path/to/output_folder" --target-years 2023
```

If the CSV files have no header row:

```bash
python RF/RF1.py --input-dir "path/to/input_csv_folder" --output-dir "path/to/output_folder" --no-header
```

Main outputs:

```text
all_predictions_2023.csv
prediction_stats_2023.csv
target_2023/
```

The same output structure is generated for `2024`.

## RF2

Use `RF2.py` when data have already been converted into line/transect format.

Expected format:

```text
line_id,point_id_on_line,year,value,lon,lat
```

`RF2.py` assumes that the 2D gridded surface has already been converted into line/transect records. The input table must already contain `line_id` and `point_id_on_line`.

Run from the repository root:

```bash
python RF/RF2.py --input-csv "path/to/input_data.csv" --output-dir "path/to/output_folder"
```

Run one target year only:

```bash
python RF/RF2.py --input-csv "path/to/input_data.csv" --output-dir "path/to/output_folder" --target-years 2024
```

If the CSV file has no header row:

```bash
python RF/RF2.py --input-csv "path/to/input_data.csv" --output-dir "path/to/output_folder" --no-header
```

Main outputs:

```text
predictions_2023.csv
line_evaluations_2023.csv
summary_2023.csv
models_2023/
```

The same output structure is generated for `2024`.

## Method Overview

`RF1.py` creates features from each independent time series:

```text
previous 3 yearly values + 3-year mean + 3-year standard deviation -> target-year value
```

`RF2.py` creates temporal and along-line spatial features, including:

```text
previous-year value
two-year lag value
3-year rolling mean
5-year rolling mean
left and right neighbor lag values
5-point along-line spatial rolling mean
1-year slope
difference from along-line spatial mean
```
