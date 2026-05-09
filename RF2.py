# -*- coding: utf-8 -*-
"""RF2 spatiotemporal Random Forest prediction.

The input CSV layout is:
line_id, point_id_on_line, year, value, lon, lat

Examples:
- target 2023 uses years before 2023 as training data.
- target 2024 uses years before 2024 as training data.
"""

import argparse
import os
import warnings
from concurrent.futures import ProcessPoolExecutor, as_completed

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestRegressor
from sklearn.metrics import r2_score
from sklearn.model_selection import GridSearchCV
from tqdm import tqdm


warnings.filterwarnings("ignore", category=FutureWarning)
pd.options.mode.chained_assignment = None

COLUMN_NAMES = ["line_id", "point_id_on_line", "year", "value", "lon", "lat"]
FEATURES = [
    "year",
    "line_id",
    "point_id_on_line",
    "value_lag_1",
    "value_lag_2",
    "rolling_mean_3y",
    "neighbor_left_lag_1",
    "neighbor_right_lag_1",
    "spatial_rolling_mean_5p",
    "value_slope_1y",
    "rolling_mean_5y",
    "spatial_diff_from_mean_5p",
]


def load_long_table(input_csv, has_header=True):
    header = 0 if has_header else None
    df = pd.read_csv(input_csv, header=header)
    if df.shape[1] < len(COLUMN_NAMES):
        raise ValueError(f"Input CSV must contain at least {len(COLUMN_NAMES)} columns.")

    df = df.iloc[:, :len(COLUMN_NAMES)].copy()
    df.columns = COLUMN_NAMES
    for col in COLUMN_NAMES:
        df[col] = pd.to_numeric(df[col], errors="coerce")
    return df.dropna(subset=["line_id", "point_id_on_line", "year"]).copy()


def add_target_rows_if_missing(df, target_year):
    """Create target-year rows from the previous year when target rows are absent."""
    if (df["year"] == target_year).any():
        return df

    previous_year = target_year - 1
    previous_df = df[df["year"] == previous_year]
    if previous_df.empty:
        raise ValueError(f"Target year {target_year} is missing and no rows were found for {previous_year}.")

    target_rows = previous_df.copy()
    target_rows["year"] = target_year
    target_rows["value"] = np.nan
    return pd.concat([df, target_rows], ignore_index=True)


def create_features_for_group(group_df):
    group_df = group_df.sort_values(by=["point_id_on_line", "year"]).copy()
    group_df["value_lag_1"] = group_df.groupby("point_id_on_line")["value"].shift(1)
    group_df["value_lag_2"] = group_df.groupby("point_id_on_line")["value"].shift(2)
    group_df["rolling_mean_3y"] = group_df.groupby("point_id_on_line")["value_lag_1"].transform(
        lambda x: x.rolling(3, 1).mean()
    )

    group_df = group_df.sort_values(by=["year", "point_id_on_line"])
    group_df["neighbor_left_lag_1"] = group_df.groupby("year")["value_lag_1"].shift(1)
    group_df["neighbor_right_lag_1"] = group_df.groupby("year")["value_lag_1"].shift(-1)
    group_df["spatial_rolling_mean_5p"] = group_df.groupby("year")["value_lag_1"].transform(
        lambda x: x.rolling(5, center=True, min_periods=1).mean()
    )
    group_df["value_slope_1y"] = group_df["value_lag_1"] - group_df["value_lag_2"]
    group_df["rolling_mean_5y"] = group_df.groupby("point_id_on_line")["value_lag_1"].transform(
        lambda x: x.rolling(5, 1).mean()
    )
    group_df["spatial_diff_from_mean_5p"] = group_df["value_lag_1"] - group_df["spatial_rolling_mean_5p"]
    return group_df


def train_evaluate_and_predict_for_line(
    line_id,
    train_line_df,
    predict_line_df,
    feature_list,
    target_col,
    models_dir,
    min_samples,
):
    try:
        if train_line_df is None or train_line_df.empty or len(train_line_df) < min_samples:
            return None
        if predict_line_df is None:
            predict_line_df = pd.DataFrame()

        X_train_line = train_line_df[feature_list]
        y_train_line = train_line_df[target_col]

        param_grid = {
            "max_depth": [6, 8],
            "min_samples_leaf": [5, 10],
        }
        rf = RandomForestRegressor(n_estimators=50, n_jobs=1, random_state=42)
        grid_search = GridSearchCV(
            estimator=rf,
            param_grid=param_grid,
            cv=2,
            n_jobs=1,
            scoring="r2",
        )
        grid_search.fit(X_train_line, y_train_line)
        line_model = grid_search.best_estimator_

        os.makedirs(models_dir, exist_ok=True)
        joblib.dump(line_model, os.path.join(models_dir, f"line_{line_id}_model.pkl"))

        train_predictions = line_model.predict(X_train_line)
        train_r2 = r2_score(y_train_line, train_predictions)
        train_line_df = train_line_df.copy()
        train_line_df["predicted_value"] = train_predictions

        test_r2 = np.nan
        if not predict_line_df.empty:
            predict_line_df = predict_line_df.copy()
            X_predict_line = predict_line_df[feature_list]
            test_predictions = line_model.predict(X_predict_line)
            predict_line_df["predicted_value"] = test_predictions

            actual_mask = predict_line_df[target_col].notna()
            if actual_mask.sum() >= 2:
                test_r2 = r2_score(predict_line_df.loc[actual_mask, target_col], test_predictions[actual_mask])

            predict_line_df["error"] = np.nan
            predict_line_df["error_rate"] = np.nan
            if actual_mask.any():
                error = (predict_line_df.loc[actual_mask, "predicted_value"] - predict_line_df.loc[actual_mask, target_col]).abs()
                predict_line_df.loc[actual_mask, "error"] = error
                nonzero_actual = actual_mask & (predict_line_df[target_col] != 0)
                predict_line_df.loc[nonzero_actual, "error_rate"] = (
                    (predict_line_df.loc[nonzero_actual, "predicted_value"] - predict_line_df.loc[nonzero_actual, target_col]).abs()
                    / predict_line_df.loc[nonzero_actual, target_col].abs()
                    * 100
                )

        return {
            "line_id": line_id,
            "train_r2": train_r2,
            "test_r2": test_r2,
            "train_results_df": train_line_df,
            "test_results_df": predict_line_df,
        }
    except Exception as exc:
        import traceback

        print(f"--- [ERROR] line_id={line_id} failed in process {os.getpid()} ---")
        print(f"Error Message: {exc}")
        traceback.print_exc()
        return None


def build_features(df, max_workers):
    groups = [group for _, group in df.groupby("line_id")]
    if max_workers == 1:
        featured_groups = [create_features_for_group(group) for group in tqdm(groups, desc="Feature engineering")]
    else:
        with ProcessPoolExecutor(max_workers=max_workers) as executor:
            featured_groups = list(
                tqdm(
                    executor.map(create_features_for_group, groups),
                    total=len(groups),
                    desc="Feature engineering",
                )
            )
    return pd.concat(featured_groups, ignore_index=True)


def run_target_year(args, all_years_df, target_year):
    print(f"\nTarget year: {target_year}")
    working_df = add_target_rows_if_missing(all_years_df, target_year)
    featured_df = build_features(working_df, args.max_workers)

    train_df = featured_df[featured_df["year"] < target_year].dropna(subset=FEATURES + ["value"]).copy()
    predict_set_df = featured_df[featured_df["year"] == target_year].dropna(subset=FEATURES).copy()

    if train_df.empty:
        print(f"No valid training rows for {target_year}.")
        return
    if predict_set_df.empty:
        print(f"No valid prediction rows for {target_year}.")
        return

    models_folder = os.path.join(args.output_dir, f"models_{target_year}")
    all_line_evaluations = []
    all_train_results_list = []
    all_test_results_list = []
    grouped_train_data = {line_id: df for line_id, df in train_df.groupby("line_id")}
    grouped_predict_data = {line_id: df for line_id, df in predict_set_df.groupby("line_id")}

    with ProcessPoolExecutor(max_workers=args.max_workers) as executor:
        futures = [
            executor.submit(
                train_evaluate_and_predict_for_line,
                line_id,
                grouped_train_data.get(line_id),
                grouped_predict_data.get(line_id),
                FEATURES,
                "value",
                models_folder,
                args.min_samples_per_line,
            )
            for line_id in grouped_train_data.keys()
        ]
        for future in tqdm(as_completed(futures), total=len(futures), desc=f"Training lines for {target_year}"):
            result = future.result()
            if result:
                all_line_evaluations.append(
                    {
                        "line_id": result["line_id"],
                        "target_year": target_year,
                        "train_r2_score": result["train_r2"],
                        "test_r2_score": result["test_r2"],
                    }
                )
                all_train_results_list.append(result["train_results_df"])
                if not result["test_results_df"].empty:
                    all_test_results_list.append(result["test_results_df"])

    if not all_line_evaluations or not all_test_results_list:
        print(f"No valid prediction results were generated for {target_year}.")
        return

    os.makedirs(args.output_dir, exist_ok=True)
    test_results_df = pd.concat(all_test_results_list, ignore_index=True)
    train_results_df = pd.concat(all_train_results_list, ignore_index=True)
    evaluations_df = pd.DataFrame(all_line_evaluations)

    predictions_path = os.path.join(args.output_dir, f"predictions_{target_year}.csv")
    evaluations_path = os.path.join(args.output_dir, f"line_evaluations_{target_year}.csv")
    summary_path = os.path.join(args.output_dir, f"summary_{target_year}.csv")
    test_results_df.to_csv(predictions_path, index=False)
    evaluations_df.to_csv(evaluations_path, index=False)

    summary = {
        "target_year": target_year,
        "train_rows": len(train_results_df),
        "prediction_rows": len(test_results_df),
        "overall_train_r2": r2_score(train_results_df["value"], train_results_df["predicted_value"]),
        "overall_test_r2": np.nan,
        "mean_error": np.nan,
        "median_error": np.nan,
        "mean_error_rate": np.nan,
        "median_error_rate": np.nan,
    }

    actual_mask = test_results_df["value"].notna()
    if actual_mask.sum() >= 2:
        summary["overall_test_r2"] = r2_score(
            test_results_df.loc[actual_mask, "value"],
            test_results_df.loc[actual_mask, "predicted_value"],
        )
        summary["mean_error"] = test_results_df.loc[actual_mask, "error"].mean()
        summary["median_error"] = test_results_df.loc[actual_mask, "error"].median()
        summary["mean_error_rate"] = test_results_df.loc[actual_mask, "error_rate"].mean()
        summary["median_error_rate"] = test_results_df.loc[actual_mask, "error_rate"].median()

    pd.DataFrame([summary]).to_csv(summary_path, index=False)
    print(f"Predictions saved to {predictions_path}")
    print(f"Summary saved to {summary_path}")


def parse_args():
    parser = argparse.ArgumentParser(
        description="Train one Random Forest per line_id and predict target-year values."
    )
    parser.add_argument("--input-csv", required=True, help="Input CSV path for line/transect records.")
    parser.add_argument("--output-dir", required=True, help="Folder where outputs and models are saved.")
    parser.add_argument(
        "--target-years",
        nargs="+",
        type=int,
        default=[2023, 2024],
        help="Target years to predict. Default: 2023 2024.",
    )
    parser.add_argument("--max-workers", type=int, default=4, help="Number of parallel worker processes.")
    parser.add_argument("--min-samples-per-line", type=int, default=50, help="Minimum training rows required per line.")
    parser.add_argument("--no-header", action="store_true", help="Use this if the input CSV has no header row.")
    return parser.parse_args()


def main():
    args = parse_args()
    os.makedirs(args.output_dir, exist_ok=True)
    all_years_df = load_long_table(args.input_csv, has_header=not args.no_header)
    for target_year in args.target_years:
        run_target_year(args, all_years_df, target_year)
    print("\nAll tasks completed.")


if __name__ == "__main__":
    main()
