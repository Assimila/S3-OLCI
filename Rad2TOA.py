
import os
import sys

HomeDir = os.path.expanduser('~')
SrcDir = os.path.join( HomeDir , '.snap/snap-python' )
sys.path.append( SrcDir )

import snappy

# Load all available operators
snappy.GPF.getDefaultInstance().getOperatorSpiRegistry().loadOperatorSpis()

HashMap = snappy.jpy.get_type('java.util.HashMap')

#Set the parameters, these can be seen from the command line using gpt -h operator
parameters = HashMap() #Specify the parameters, these can be seen from the command line using gpt -h operator
parameters.put('sensor','OLCI') 
parameters.put('copyNonSpectralBands','False') # I had to use this option due to an error 

source = snappy.ProductIO.readProduct('xfdumanifest.xml')
# compute the product from S3 source product
refl_product = GPF.createProduct( 'Rad2Refl', parameters, source ) # compute the product from input called sub_product



cmd=$HOME/snap/bin/gpt
operator=Rad2Refl

source_file=$1
target_file=$2

format=GeoTIFF

echo $cmd $operator -t $target_file -f $format $source_file
$cmd $operator -t $target_file -f $format $source_file

