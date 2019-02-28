#!/bin/bash -x

DATADIR=/data/Sentinel3/OLCI/h17v05
year=2017

mkdir -p $DATADIR/QL

for DoY in 154 157 159 162
do
    image=`ls -d $DATADIR/$year$DoY/*`
    gdal_translate -of GTiff -ot Byte -scale 0.01 0.35 0 255 $image/Oa09_reflectance.h17v05.tif b9.tif
    gdal_translate -of GTiff -ot Byte -scale 0.02 0.40 0 255 $image/Oa06_reflectance.h17v05.tif b6.tif
    gdal_translate -of GTiff -ot Byte -scale 0.01 0.45 0 255 $image/Oa03_reflectance.h17v05.tif b3.tif

    convert b9.tif b6.tif b3.tif -font AvantGarde-Book -gravity South \
        -pointsize 40 -fill white -draw 'text 10,18 " '$image'' -channel RGB -combine $image.963.RGB.png

    rm b?.tif
done

#convert -loop 0 -delay 100 *963.RGB.png OLCI.gif
#mv *RGB.png *.gif $DATADIR/QL

mv $DATADIR/*/*RGB.png $DATADIR/QL
