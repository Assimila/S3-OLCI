#!/bin/bash

export GDAL_DATA=`gdal-config --datadir`
export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:."

PRODUCT="S3A_OL_1_EFR____"

TILE=$1
DATADIR=/data/Sentinel3/OLCI/L1B/$TILE     # e.g. /data/Sentinel3/OLCI/L1B/h18v04
OUTPUTDIR=/data/Sentinel3/OLCI/$TILE       # e.g. /data/Sentinel3/OLCI/h18v04

# S3 Toolbox bin dir
S3TBX_DIR=$HOME/snap/bin
# Source code dir
SRCDIR=$HOME/tmp/Projects/Multiply/S3

for day in `ls -d $DATADIR/*SEN3 | cut -d_ -f 8 | sort | cut -dT -f1 | uniq`
do

    julian_date=`echo $day | date -d$day +%Y%j`

    if [ -e $OUTPUTDIR/$julian_date ]; then
        # If output product already exist, process next one
        echo "$day already processed, jumping to next one..."
        continue
    fi

    WORKDIR=$$
    mkdir /tmp/$WORKDIR

    InputFiles=`ls -d $DATADIR/${PRODUCT}${day}*`
    for INPUTFILE in $InputFiles
    do
        cd /tmp/$WORKDIR
        tmpdir=`basename $INPUTFILE`
        echo "Processing $tmpdir..."
        mkdir $tmpdir
        cd $tmpdir

        # Transform S3 radiances to TOA reflectances
        # ------------------------------------------
        # S3TBX graph to be processed
        graph=OLCI_rad2refl.xml
        cp $SRCDIR/helpers/$graph .
        # set input file in graph
        sed -i "s:PATH:$INPUTFILE:g" $graph

        # Run the S3TBX graph
        $S3TBX_DIR/gpt $graph -t Rad2Refl

        # Reproject to MODIS Sinusoidal
        # -----------------------------
        # tile xmin ymin xmax ymax
        tiles_file=$SRCDIR/tiles.txt
        xmin=`awk -v tile="$TILE" '{ if ( $1 == tile ) { print $2 } }' $tiles_file`
        ymin=`awk -v tile="$TILE" '{ if ( $1 == tile ) { print $3 } }' $tiles_file`
        xmax=`awk -v tile="$TILE" '{ if ( $1 == tile ) { print $4 } }' $tiles_file`
        ymax=`awk -v tile="$TILE" '{ if ( $1 == tile ) { print $5 } }' $tiles_file`

        cd Rad2Refl.data
        # Expand tie point layers
        python $SRCDIR/expandTiePointLayers.py /tmp/$WORKDIR/$tmpdir/Rad2Refl.dim

        # Add geolocation info to each TOA reflectance file
        # geolocation metadata file
        geo_metadata=geo_metadata.xml
        cp $SRCDIR/helpers/geo_metadata.xml .

        for file in `ls *reflectance.img quality_flags.img ???.tif`
        do
            vrt_file=`basename $file`.vrt
            gdal_translate -of VRT $file $vrt_file

            # Insert geocoding from Lat/Lon files in the VRT
            file_type=`echo $file | cut -d. -f2`
            if [ $file_type == "tif" ]
            then
                sed -i "1r geo_metadata.xml" $vrt_file
            else
                sed -i "4r geo_metadata.xml" $vrt_file
            fi

            # Reproject to LatLon
            gdalwarp -geoloc -t_srs EPSG:4326 $vrt_file tmp_LatLon.tif

            # Reproject to MODIS Sinusoidal and match tile extent
            output_file=`basename $file | cut -d. -f1`.$TILE.tif
            gdalwarp \
                -t_srs '+proj=sinu +lon_0=0 +x_0=0 +y_0=0 +a=6371007.181 +b=6371007.181 +units=m +no_defs ' \
                -te $xmin $ymin $xmax $ymax \
                -tr 463.312719959778804 -463.312716551443543 \
                tmp_LatLon.tif $output_file

            rm tmp_LatLon.tif

        done

        # Masking
        python $SRCDIR/OLCI_L1B_QA_masking.py

    done

    # if there are several daily images, create daily mosaic
    cd /tmp/$WORKDIR
    if [ `ls -d ${PRODUCT}* | wc -l` -gt 1 ]; then
        for file in `ls ${PRODUCT}*/Rad2Refl.data/*$TILE*.tif | cut -d/ -f3 | sort | uniq`
        do
            gdalwarp -srcnodata 0.0 -dstnodata 0.0 \
                -co "COMPRESS=LZW" -co "INTERLEAVE=BAND" -co "TILED=YES" \
                ${PRODUCT}*/Rad2Refl.data/$file $file
        done

        # Observation time
        first_obs_time=`ls -d ${PRODUCT}* | head -1 | cut -d_ -f8`
        last_obs_time=`ls -dr ${PRODUCT}* | head -1 | cut -d_ -f9`

        cd /tmp/$WORKDIR
        # Move products to output directory
        mkdir -p $OUTPUTDIR/$julian_date/${PRODUCT}${first_obs_time}_${last_obs_time}
        mv *$TILE*.tif $OUTPUTDIR/$julian_date/${PRODUCT}${first_obs_time}_${last_obs_time}
    else
        # Observation time
        first_obs_time=`ls -d ${PRODUCT}* | cut -d_ -f8` 
        last_obs_time=`ls -d ${PRODUCT}* | cut -d_ -f9` 

        cd /tmp/$WORKDIR    
        # Move products to output directory
        mkdir -p $OUTPUTDIR/$julian_date/${PRODUCT}${first_obs_time}_${last_obs_time}
        mv */Rad2Refl.data/*$TILE*.tif $OUTPUTDIR/$julian_date/${PRODUCT}${first_obs_time}_${last_obs_time}
    fi

    # Delete work directory
    rm -rf /tmp/$WORKDIR

done

