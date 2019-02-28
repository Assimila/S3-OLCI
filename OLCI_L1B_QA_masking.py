
import sys
import os
import glob

try:
    import numpy as np
except ImportError:
    print('Numpy is not installed.')
    exit(-1)

try:
    import osgeo.gdal as gdal
    from osgeo.gdalconst import *
    gdal.UseExceptions()
except ImportError:
    print('GDAL is not installed.')
    exit(-1)

from IPython import embed

Files = glob.glob( 'Oa??_reflectance.h??v??.tif' )
Files.sort()

for File in Files:
    print(File)
    dataset = gdal.Open( File )
    rows, cols = dataset.RasterYSize, dataset.RasterXSize

    # Get projection information
    Projection = dataset.GetProjection()
    GeoTransform = dataset.GetGeoTransform()
    data = dataset.ReadAsArray()
    dataset = None

    # QA information
    # Bit 3 Land
    # Bit 4 Cloud
    # Bit 5 Snow/Ice

    QA_file = glob.glob( 'quality_flags.h??v??.tif' )
    dataset = gdal.Open( QA_file[0] )
    QA = dataset.ReadAsArray()

    Land = np.where ( ( QA == -2143289344 ) | 
                      ( QA == -2147483648 ) |
                      ( QA == -2139095040 ) |
                      ( QA == -2134900736 ) , 1, 0 )
    
    # Save masked refl to a GeoTiff file
    format = "GTiff"
    driver = gdal.GetDriverByName(format)

    # fname e.g. MOD09GA.A2015235.h17v03.006.2015305215014.hdf
    fname = os.path.basename( File )
    band, tile, file_format = fname.split('.')
    fname = '%s.%s.masked.%s' % ( band, tile, file_format ) 

    # Seven spectral bands plus uncert and snow mask
    new_dataset = driver.Create( fname, cols, rows, 1, 
                  GDT_Float32 , options=["COMPRESS=LZW", "INTERLEAVE=BAND", "TILED=YES"] )

    data = data * Land
    data = np.nan_to_num( data )
    new_dataset.GetRasterBand( 1 ).WriteArray( data )

    new_dataset.SetProjection( Projection )
    new_dataset.SetGeoTransform( GeoTransform )

    new_dataset = None
