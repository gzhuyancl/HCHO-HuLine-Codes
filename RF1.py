# -*- coding: utf-8 -*-
"""RF1 temporal Random Forest prediction.

The input CSV layout is:
metadata columns first, followed by yearly value columns starting at 2005.

Examples:
- target 2023 uses 2005-2022 as training values.
- target 2024 uses 2005-2023 as training values.
"""

import argparse
import glob
import logging
import os
from concurrent.futures import ProcessPoolExecutor, as_completed

import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.model_selection import RandomizedSearchCV, TimeSeriesSplit
from tqdm import tqdm


DEFAULT_TARGET_YEARS = [2023, 2024]
DEFAULT_METADATA_NAMES = ["Longitude", "Latitude", "X", "Y", "Col5", "Col6"]


def configure_logging(output_directory):
    os.makedirs(output_directory, exist_ok=True)
    log_path = os.path.join(output_directory, "batch_prediction.log")
    logging.basicConfig(
        filename=log_path,
        filemode="w",
        format="%(asctime)s - %(levelname)s - %(message)s",
        level=logging.INFO,
    )


def metadata_names(metadata_cols):
    if metadata_cols == len(DEFAULT_METADATA_NAMES):
        return DEFAULT_METADATA_NAMES
    return [f"Meta_{i + 1}" for i in range(metadata_cols)]


def fallback_prediction(coeff_series, steps):
    valid_values = coeff_series[~np.isnan(coeff_series)]
    last_value = valid_values[-1] if len(valid_values) else np.nan
    return np.concatenate([coeff_series, [last_value] * steps])


def create_features(coeff_series, lags=3):
    """Create lag features plus rolling mean and rolling standard deviation."""
    X, y = [], []
    for i in range(len(coeff_series) - lags):
        lag_features = coeff_series[i:i + lags]
        moving_avg = np.mean(lag_features)
        moving_std = np.std(lag_features)
        X.append(list(lag_features) + [moving_avg, moving_std])
        y.append(coeff_series[i + lags])
    return np.array(X), np.array(y)


def tune_rf(X, y, rf_n_jobs=1):
    """Tune Random Forest hyperparameters with time-series cross validation."""
    if len(X) < 2:
        raise ValueError("Not enough training samples after creating lag features.")

    rf = RandomForestRegressor(random_state=42)
    param_dist = {
        "n_estimators": [100, 200],
        "max_depth": [None, 5, 10],
        "min_samples_split": [2, 5],
        "min_samples_leaf": [1, 2],
        "max_features": ["sqrt", "log2", 0.5, None],
    }
    n_splits = min(5, len(X) - 1)
    tscv = TimeSeriesSplit(n_splits=n_splits)
    random_search = RandomizedSearchCV(
        estimator=rf,
        param_distributions=param_dist,
        n_iter=10,
        cv=tscv,
        scoring="neg_mean_squared_error",
        random_state=42,
        n_jobs=rf_n_jobs,
        verbose=0,
    )
    random_search.fit(X, y)
    logging.info(
        "Best Random Forest parameters: %s, MSE: %.6f",
        random_search.best_params_,
        -random_search.best_score_,
    )
    return random_search.best_estimator_


def fit_rf_and_predict(coeff_series, steps=1, lags=3, rf_n_jobs=1):
    """Fit a Random Forest model and recursively predict future values."""
    coeff_series = np.asarray(coeff_series, dtype=float)
    try:
        if len(coeff_series) <= lags or np.isnan(coeff_series).any():
            raise ValueError("Training series is too short or contains missing values.")

        X, y = create_features(coeff_series, lags)
        best_rf = tune_rf(X, y, rf_n_jobs=rf_n_jobs)

        predictions = []
        input_seq = coeff_series[-lags:].tolist()
        for _ in range(steps):
            lag_features = input_seq[-lags:]
            moving_avg = np.mean(lag_features)
            moving_std = np.std(lag_features)
            input_features = lag_features + [moving_avg, moving_std]
            next_pred = best_rf.predict([input_features])[0]
            predictions.append(next_pred)
            input_seq.append(next_pred)
        return np.concatenate([coeff_series, predictions])
    except Exception as exc:
        logging.error("Random Forest model fitting error: %s. Using last value.", exc)
        return fallback_prediction(coeff_series, steps)


def process_single_file(
    file_path,
    output_directory,
    target_year,
    start_year,
    metadata_cols,
    lags,
    rf_n_jobs,
    has_header,
):
    """Process one CSV file and save target-year predictions."""
    file_name = os.path.basename(file_path)
    try:
        header = 0 if has_header else None
        df = pd.read_csv(file_path, header=header)

        training_end_col = metadata_cols + (target_year - start_year)
        actual_col = training_end_col
        if df.shape[1] < training_end_col:
            logging.warning(
                "File %s has fewer than %s columns for target year %s. Skipping.",
                file_name,
                training_end_col,
                target_year,
            )
            return None

        time_series_data = df.iloc[:, metadata_cols:training_end_col].apply(pd.to_numeric, errors="coerce")
        coordinates = df.iloc[:, :metadata_cols]

        if df.shape[1] > actual_col:
            actual_values = pd.to_numeric(df.iloc[:, actual_col], errors="coerce")
        else:
            actual_values = pd.Series(np.nan, index=df.index)

        rows = []
        meta_names = metadata_names(metadata_cols)
        for group_idx, (row_idx, row) in enumerate(time_series_data.iterrows(), start=1):
            train_data = row.to_numpy(dtype=float)
            predictions = fit_rf_and_predict(
                train_data,
                steps=1,
                lags=lags,
                rf_n_jobs=rf_n_jobs,
            )
            predicted_value = predictions[-1]
            actual_value = actual_values.loc[row_idx]
            error = abs(predicted_value - actual_value) if pd.notna(actual_value) else np.nan
            error_rate = (
                abs((predicted_value - actual_value) / actual_value * 100)
                if pd.notna(actual_value) and actual_value != 0
                else np.nan
            )

            result_row = {
                "File": file_name,
                "Group": group_idx,
                "Target_Year": target_year,
            }
            for name, value in zip(meta_names, coordinates.loc[row_idx].tolist()):
                result_row[name] = value
            result_row.update(
                {
                    f"Predicted_{target_year}": predicted_value,
                    f"Actual_{target_year}": actual_value,
                    "Error": error,
                    "Error_Rate": error_rate,
                }
            )
            rows.append(result_row)

        results_df = pd.DataFrame(rows)
        output_file_name = f"{os.path.splitext(file_name)[0]}_predictions_{target_year}.csv"
        output_file_path = os.path.join(output_directory, output_file_name)
        results_df.to_csv(output_file_path, index=False)
        logging.info("Predictions saved to %s", output_file_path)
        return results_df
    except Exception as exc:
        logging.error("Error processing file %s: %s", file_name, exc)
        return None


def run_target_year(args, target_year):
    target_output_dir = os.path.join(args.output_dir, f"target_{target_year}")
    os.makedirs(target_output_dir, exist_ok=True)

    csv_files = glob.glob(os.path.join(args.input_dir, "*.csv"))
    if not csv_files:
        raise SystemExit(f"No CSV files found in input directory: {args.input_dir}")

    all_results = []
    with ProcessPoolExecutor(max_workers=args.max_workers) as executor:
        future_to_file = {
            executor.submit(
                process_single_file,
                file_path,
                target_output_dir,
                target_year,
                args.start_year,
                args.metadata_cols,
                args.lags,
                args.rf_n_jobs,
                not args.no_header,
            ): file_path
            for file_path in csv_files
        }
        for future in tqdm(as_completed(future_to_file), total=len(future_to_file), desc=f"Predicting {target_year}"):
            result = future.result()
            if result is not None and not result.empty:
                all_results.append(result)

    if not all_results:
        print(f"No valid prediction results were generated for {target_year}.")
        return

    all_results_df = pd.concat(all_results, ignore_index=True)
    total_output_path = os.path.join(args.output_dir, f"all_predictions_{target_year}.csv")
    all_results_df.to_csv(total_output_path, index=False)

    actual_col = f"Actual_{target_year}"
    actual_mask = all_results_df[actual_col].notna()
    if actual_mask.any():
        stats = {
            "Target_Year": target_year,
            "Total_Samples": len(all_results_df),
            "Samples_With_Actual": int(actual_mask.sum()),
            "Mean_Error": all_results_df.loc[actual_mask, "Error"].mean(),
            "Median_Error": all_results_df.loc[actual_mask, "Error"].median(),
            "Mean_Error_Rate": all_results_df.loc[actual_mask, "Error_Rate"].mean(),
            "Median_Error_Rate": all_results_df.loc[actual_mask, "Error_Rate"].median(),
        }
        stats_output_path = os.path.join(args.output_dir, f"prediction_stats_{target_year}.csv")
        pd.DataFrame([stats]).to_csv(stats_output_path, index=False)
        print(f"Statistics saved to {stats_output_path}")

    print(f"All predictions for {target_year} saved to {total_output_path}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="RF1 temporal Random Forest prediction for target-year values."
    )
    parser.add_argument("--input-dir", required=True, help="Folder containing input CSV files.")
    parser.add_argument("--output-dir", required=True, help="Folder where prediction results are saved.")
    parser.add_argument(
        "--target-years",
        nargs="+",
        type=int,
        default=DEFAULT_TARGET_YEARS,
        help="Target years to predict. Default: 2023 2024.",
    )
    parser.add_argument("--start-year", type=int, default=2005, help="First yearly value column. Default: 2005.")
    parser.add_argument("--metadata-cols", type=int, default=6, help="Number of metadata columns before yearly values.")
    parser.add_argument("--lags", type=int, default=3, help="Number of lag values used as model features.")
    parser.add_argument("--max-workers", type=int, default=4, help="Number of files processed in parallel.")
    parser.add_argument("--rf-n-jobs", type=int, default=1, help="Parallel jobs inside RandomizedSearchCV.")
    parser.add_argument("--no-header", action="store_true", help="Use this if input CSV files have no header row.")
    return parser.parse_args()


def main():
    args = parse_args()
    configure_logging(args.output_dir)
    for target_year in args.target_years:
        run_target_year(args, target_year)


if __name__ == "__main__":
    main()
