# S3-OLCI

## S3_Rad2TOA_reproj2_MODIS_Sin

It works with OLCI product [S3A_OL_1_EFR](https://ladsweb.modaps.eosdis.nasa.gov/missions-and-measurements/products/olci-L0L1/S3A_OL_1_EFR/) at 300m. The full resolution is required in order to resample to the 500m MODIS resolution.

* Script requires as an input parameter the MODIS tile, e.g. h18v04
* It wll read all availables images in DATADIR
* Output products will be stored in OUTPUTDIR
* A config file tiles.txt [tiles.txt](https://github.com/Assimila/S3-OLCI/blob/master/tiles.txt) is required to get the corner coordinates used to perform the gridding and reprojection to the MODIS Sinusoidal Grid.
* SNAP is required to perform the TOA radiances to TOA reflectances transformation.

* For every file:
    * TOA radiances to TOA reflectances transformation using the [OLCI_rad2refl.xml](https://github.com/Assimila/S3-OLCI/blob/master/helpers/OLCI_rad2refl.xml) graph file.
    * Extracting the coordinates for the selected tile.
    * Two rasters with latitudes and longitudes are created from the Rad2Refl.dim product tie point layers using [expandTiePointLayers.py](https://github.com/Assimila/S3-OLCI/blob/master/expandTiePointLayers.py). Additionally, all angular infromation is extracted, e.g. viewing and solar...
    * For every band:
        * A GDAL VRT file is created and the geolocation information is updated in geo_metadata.xml
        * Reprojection to Lat/Lon EPSG:4326 is performed using gdalwarp and the expanded Lat/Lon coordinates from the previous step. This was neccesary because a reprojection to Sinusoidal using SNAP produced a raster with a shift, some background information in [here](https://forum.step.esa.int/t/best-practice-to-convert-and-reproject-sentinel-3-radiances-to-reflectance/5744/6)
        * Reprojection and regridding to MODIS Sinusoidal is performed using gdalwarp
     * A mask is applied
  * A mosaic is created if needed
