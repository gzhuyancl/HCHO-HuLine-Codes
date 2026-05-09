
### Minimal Python example for accessing OMI HCHO Oversampling Dataset ###


import xarray as xr
import matplotlib.pyplot as plt

# Open dataset
ds = xr.open_dataset(r"D:\test\OMI_HCHO_Global_2005-01-01_2005-06-30_Res_0.1_PL_5.nc")

# Extract China region
china_subset = ds.sel(lat=slice(15, 55), lon=slice(70, 140))

# Convert data from molecules cm-2 to 1e15 molecules cm-2
data_in_1e15 = china_subset['Average_grids'] / 1e15

# Create plot
fig, ax = plt.subplots(1, 1, figsize=(10, 6))

# Plot with converted data
plot_obj = data_in_1e15.plot(
    ax=ax,
    cmap='RdYlBu_r',
    vmin=0,
    vmax=20,
    add_colorbar=False
)

# Add colorbar with custom ticks
cbar = fig.colorbar(plot_obj, ax=ax, orientation='horizontal',
                   pad=0.1, shrink=0.8)
cbar.set_ticks([0, 5, 10, 15, 20])
cbar.set_label('HCHO Column Density (10$^{15}$ molecules cm$^{-2}$)', fontsize=12)

# Set axis labels
ax.set_xlabel('Longitude')
ax.set_ylabel('Latitude')
ax.set_title('HCHO Average Concentration')

plt.tight_layout()
plt.show()

ds.close()
