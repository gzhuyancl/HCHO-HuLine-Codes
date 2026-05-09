### Code for converting RData to NetCDF ###

import xarray as xr
import numpy as np
import pyreadr
import glob
import os
from datetime import datetime
import re


def convert_rdata_to_nc_with_all_fields():
    input_folder_path = r'G:\OMIHCHO_Oversampling\grid_data\1\1_12month'
    output_folder_path = r'H:\convert_data_nc\1\1_12month'

    # Specify resolution
    resolution = 1

    # Ensure output directory exists
    os.makedirs(output_folder_path, exist_ok=True)

    rdata_files = glob.glob(os.path.join(input_folder_path, 'OMI_HCHO_Global_*.RData'))

    print(f"Found {len(rdata_files)} RData files to process")

    for rdata_file in rdata_files:
        try:
            print(f"Processing: {os.path.basename(rdata_file)}")

            # Read RData file
            mon = pyreadr.read_r(rdata_file)

            # Check if all required fields exist
            required_fields = ['Average_grids', 'Average_UNC_grids', 'UNC_to_Average']
            missing_fields = [field for field in required_fields if field not in mon]

            if missing_fields:
                print(f"Warning: Missing fields {missing_fields} in {rdata_file}")
                continue

            # Extract time information from filename
            filename = os.path.basename(rdata_file)
            time_period = extract_time_from_filename(filename)

            # Get data and handle missing values
            def process_data(data):
                data = data.astype(np.float32)
                return data.values if hasattr(data, 'values') else data

            avg_grids = process_data(mon['Average_grids'])
            unc_grids = process_data(mon['Average_UNC_grids'])
            ratio_data = process_data(mon['UNC_to_Average'])

            print(f"Original data shape: {avg_grids.shape}")

            lat_range = 200
            lon_range = 400

            # Calculate expected data points
            expected_lat_points = int(lat_range / resolution)  # Latitude direction points
            expected_lon_points = int(lon_range / resolution)  # Longitude direction points

            print(f"Expected data shape: ({expected_lat_points}, {expected_lon_points})")

            # Create latitude/longitude coordinates
            lat = np.arange(-100, 100, resolution)
            lon = np.arange(-200, 200, resolution)

            print(f"Latitude points: {len(lat)}, Longitude points: {len(lon)}")

            # Check data shape and ensure correct dimension order
            if avg_grids.shape == (expected_lon_points, expected_lat_points):
                print("Transposing data from (lon, lat) to (lat, lon) order")
                avg_grids = avg_grids.T
                unc_grids = unc_grids.T
                ratio_data = ratio_data.T
            elif avg_grids.shape != (expected_lat_points, expected_lon_points):
                print(
                    f"Warning: Unexpected data shape {avg_grids.shape}, expected ({expected_lat_points}, {expected_lon_points}) or ({expected_lon_points}, {expected_lat_points})")
                avg_grids = avg_grids[:expected_lat_points, :expected_lon_points]
                unc_grids = unc_grids[:expected_lat_points, :expected_lon_points]
                ratio_data = ratio_data[:expected_lat_points, :expected_lon_points]

            print(f"Final data shape: {avg_grids.shape}")

            # Ensure coordinate length matches data shape
            lat = lat[:avg_grids.shape[0]]
            lon = lon[:avg_grids.shape[1]]

            # Check missing values in data
            def check_missing_values(data, name):
                nan_count = np.isnan(data).sum()
                inf_count = np.isinf(data).sum()
                total_count = data.size
                print(
                    f"  {name}: {nan_count}/{total_count} NaN values ({nan_count / total_count * 100:.1f}%), {inf_count} Inf values")
                return nan_count > 0

            print("Missing values check:")
            has_nan_avg = check_missing_values(avg_grids, 'Average_grids')
            has_nan_unc = check_missing_values(unc_grids, 'Average_UNC_grids')
            has_nan_ratio = check_missing_values(ratio_data, 'UNC_to_Average')

            # Create Dataset
            ds = xr.Dataset()

            # Add Average_grids field
            ds['Average_grids'] = xr.DataArray(
                data=avg_grids,
                dims=['lat', 'lon'],
                coords={'lat': lat, 'lon': lon},
                attrs={
                    'long_name': 'Average HCHO Vertical Column Density',
                    'units': '1e15 molecules cm-2',
                    'missing_value': np.nan,
                    'description': 'Average formaldehyde vertical column density from Oversampling'
                }
            )

            # Add Average_UNC_grids field
            ds['Average_UNC_grids'] = xr.DataArray(
                data=unc_grids,
                dims=['lat', 'lon'],
                coords={'lat': lat, 'lon': lon},
                attrs={
                    'long_name': 'Average HCHO Uncertainty',
                    'units': '1e14 molecules cm-2',
                    'missing_value': np.nan,
                    'description': 'Uncertainty of average formaldehyde vertical column density'
                }
            )

            # Add UNC_to_Average field
            ds['UNC_to_Average'] = xr.DataArray(
                data=ratio_data,
                dims=['lat', 'lon'],
                coords={'lat': lat, 'lon': lon},
                attrs={
                    'long_name': 'Uncertainty to Average VCD Ratio',
                    'units': 'dimensionless',
                    'missing_value': np.nan,
                    'description': 'Ratio of uncertainty to average VCD value'
                }
            )

            # Add coordinate attributes
            ds['lat'].attrs = {
                'long_name': 'latitude',
                'units': 'degrees_north',
                'standard_name': 'latitude',
                'axis': 'Y'
            }

            ds['lon'].attrs = {
                'long_name': 'longitude',
                'units': 'degrees_east',
                'standard_name': 'longitude',
                'axis': 'X'
            }

            # Add global attributes
            global_attrs = {
                'title': 'OMI HCHO Level-3 Oversampling Data',
                'source': 'OMI satellite observations',
                'history': f'Created on {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}',
                'conventions': 'CF-1.8',
                'platform': 'Aura',
                'instrument': 'OMI',
                'product': 'HCHO Vertical Column Density',
                'creation_date': datetime.now().strftime("%Y-%m-%d"),
                'spatial_resolution': f'{resolution} degrees',
                'grid_resolution': resolution,
                'grid_dimensions': f'{avg_grids.shape[0]} x {avg_grids.shape[1]} (lat x lon)',
                'data_order': 'lat, lon (latitude, longitude)',
                'missing_data_value': 'NaN',
                'original_missing_value': 'NA (RData format)'
            }

            # Add time information extracted from filename
            if time_period:
                global_attrs['time_coverage_start'] = time_period[0]
                global_attrs['time_coverage_end'] = time_period[1]
                global_attrs['time_period'] = f"{time_period[0]} to {time_period[1]}"

            # Add geographic range information
            global_attrs['geospatial_lat_min'] = float(lat.min())
            global_attrs['geospatial_lat_max'] = float(lat.max())
            global_attrs['geospatial_lon_min'] = float(lon.min())
            global_attrs['geospatial_lon_max'] = float(lon.max())
            global_attrs['geospatial_lat_units'] = 'degrees_north'
            global_attrs['geospatial_lon_units'] = 'degrees_east'

            ds.attrs = global_attrs

            # Generate output file path
            nc_filename = os.path.basename(rdata_file).replace('.RData', '.nc')
            nc_path = os.path.join(output_folder_path, nc_filename)

            # Save as NetCDF file
            encoding = {
                'Average_grids': {
                    'dtype': 'float32',
                    'zlib': True,
                    'complevel': 1,
                    '_FillValue': np.nan
                },
                'Average_UNC_grids': {
                    'dtype': 'float32',
                    'zlib': True,
                    'complevel': 1,
                    '_FillValue': np.nan
                },
                'UNC_to_Average': {
                    'dtype': 'float32',
                    'zlib': True,
                    'complevel': 1,
                    '_FillValue': np.nan
                },
                'lat': {'dtype': 'float64'},
                'lon': {'dtype': 'float64'}
            }

            ds.to_netcdf(nc_path, format='NETCDF4_CLASSIC', encoding=encoding)

            print(f"  Successfully processed: {nc_filename}")

        except Exception as e:
            print(f"✗ Error processing {rdata_file}: {str(e)}")
            import traceback
            traceback.print_exc()
            continue


def extract_time_from_filename(filename):
    try:
        # Match format: OMI_HCHO_Global_2005-01-01_2005-12-31_Res_0.05_PL_5.RData
        pattern = r'OMI_HCHO_Global_(\d{4}-\d{2}-\d{2})_(\d{4}-\d{2}-\d{2})_'
        match = re.search(pattern, filename)
        if match:
            start_date = match.group(1)
            end_date = match.group(2)
            return (start_date, end_date)
    except:
        pass
    return None


if __name__ == "__main__":
    # Convert all RData files
    convert_rdata_to_nc_with_all_fields()

    print("\nProcessing completed!")
