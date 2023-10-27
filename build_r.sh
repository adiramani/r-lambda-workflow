#!/bin/bash

# modified from https://github.com/bakdata/aws-lambda-r-runtime/blob/master/r/compile.sh, https://github.com/Appsilon/r-lambda-workflow

# Create base EC2 instance, run the following code inside of it, 
# DO NOT USE AN ARM or AL 2023 instance

set -euo pipefail

VERSION=$1

if [ -z "$VERSION" ];
then
    echo 'version number required'
    exit 1
fi


sudo mkdir build/
cd build/

wget https://cran.r-project.org/src/base/R-4/R-$VERSION.tar.gz

sudo mkdir -p /opt/R/
sudo chown -R $(whoami) /opt/R/

sudo tar -xf R-$VERSION.tar.gz
sudo mv R-$VERSION/* /opt/R

sudo rm R-$VERSION.tar.gz

sudo yum install -y readline-devel \
    xorg-x11-server-devel libX11-devel libXt-devel \
    gcc-c++ gcc-gfortran \
    zlib-devel bzip2 bzip2-libs

sudo yum downgrade curl-7.88.1 libcurl-7.88.1

cd /opt/R/
mkdir /opt/R/bin
cp /usr/bin/which /opt/R/bin/
export WHICH="/opt/R/bin/which"
sudo chown -R $(whoami) /opt/R/


./configure --prefix=/opt/R/ --exec-prefix=/opt/R/ --with-libpth-prefix=/opt/ --with-pcre2 --enable-R-shlib
make

sudo cp /usr/lib64/libgfortran.so.4 lib/
sudo cp /usr/lib64/libgomp.so.1 lib/
sudo cp /usr/lib64/libquadmath.so.0 lib/
sudo cp /usr/lib64/libstdc++.so.6 lib/
sudo cp /usr/lib64/libpcre2-8.so.0 lib/

sudo yum install -y openssl-devel libxml2-devel

sudo ./bin/Rscript -e 'chooseCRANmirror(graphics=FALSE, ind=34); install.packages(c("httr", "aws.s3", "logging", "Rcpp", "dplyr", "jsonlite"))'

sudo zip -r -q ~/build/R.zip bin/ lib/ etc/ library/ doc/ modules/ share/

cd ~/build/
sudo mkdir -p layers/
sudo unzip -q R.zip -d layers/R/
sudo rm -r layers/R/doc/manual/

# upload all files in src from https://github.com/bakdata/aws-lambda-r-runtime/blob/master/runtime/src/runtime.R
sudo cp src/* layers/

cd layers/
sudo chmod -R 755 .
sudo zip -r -q runtime-$VERSION.zip .
sudo mkdir -p ~/build/dist/
sudo mv runtime-$VERSION.zip ~/build/dist/
