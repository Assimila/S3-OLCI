
import sys
import os
import xml.etree.ElementTree as ET
import osgeo.gdal as gdal
import numpy as np
from IPython import embed

# Dimap file
Dimap_fname = sys.argv[1]
Dimap_fdir = os.path.dirname( Dimap_fname )
tree = ET.parse( Dimap_fname )
root = tree.getroot()
TiePointsVars = root.findall( 'Tie_Point_Grids/Tie_Point_Grid_Info' )
tie_point_fnames = root.findall( 'Data_Access/Tie_Point_Grid_File' )

# Read angular information layers
bands = [ 'OAA', 'OZA', 'SAA', 'SZA' ]

for tie_point_var in TiePointsVars:
    tie_point_grid_name = tie_point_var.find( 'TIE_POINT_GRID_NAME' ).text
    if tie_point_grid_name in bands :
        grid_index = int( tie_point_var.find( 'TIE_POINT_GRID_INDEX' ).text ) 
        step_x = float( tie_point_var.find( 'STEP_X' ).text )

        # Read layer
        tie_point_fname = tie_point_fnames[ grid_index ].find( 'TIE_POINT_GRID_FILE_PATH' ).attrib[ 'href' ]
        # DIMAP files are ENVI files, the img data file should
        # be opened instead of the hdr header file
        tie_point_fname = tie_point_fname.replace( 'hdr', 'img' )
        tie_point_fname = os.path.join( Dimap_fdir, tie_point_fname )
        # Get data
        print(tie_point_fname)
        tie_point_data = gdal.Open( tie_point_fname ).ReadAsArray()

        # Expand tie point
        tie_point_rows, tie_point_cols = tie_point_data.shape
        expanded_tie_point_cols = int( ( ( tie_point_cols * step_x ) - step_x ) + 1 )

        # Expanded array
        expanded_data = np.zeros( ( tie_point_rows, expanded_tie_point_cols ), tie_point_data.dtype )

        for row in range( tie_point_rows ):
            # The x-coordinates of the interpolated values
            x = np.arange( 0, expanded_tie_point_cols ).astype( np.int16 )
            # The x-coordinates of the data points
            xp = np.arange( 0, tie_point_cols * step_x, step_x ).astype( np.int16 )
            # The y-coordinates of the data points, same length as xp
            fp = tie_point_data[ row, : ]

            expanded_data[ row, : ] = np.interp(x, xp, fp)

        # Save expanded tie point
        print(tie_point_grid_name, "Writing results to a file...")
        format = "GTiff"
        driver = gdal.GetDriverByName(format)
        fname = '%s.tif' % ( tie_point_grid_name )

        new_dataset = driver.Create( fname, \
          expanded_tie_point_cols, tie_point_rows, 1, gdal.GDT_Float32 )
          #gdal.GDT_Float32, options=["COMPRESS=LZW", "INTERLEAVE=BAND", "TILED=YES"] )

        new_dataset.GetRasterBand( 1 ).WriteArray( expanded_data )
        new_dataset = None
                
        #ipshell = embed()


# For Lat Lon layers, only apply scale factor
scale_factor = 0.000001

for location_var in [ 'latitude', 'longitude' ] :
    fname = '%s.img' % ( location_var )
    print("Applying scale factor to", location_var)
    layer = gdal.Open( fname ).ReadAsArray()
    rows, cols = layer.shape
    layer = layer * scale_factor
    new_dataset = driver.Create( '%s.tif' % ( location_var ) , cols, rows, 1, gdal.GDT_Float32 )
        #gdal.GDT_Float32, options=["COMPRESS=LZW", "INTERLEAVE=BAND", "TILED=YES"] )

    new_dataset.GetRasterBand( 1 ).WriteArray( layer )
    new_dataset = None

