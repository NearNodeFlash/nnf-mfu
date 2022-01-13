#!/bin/bash

# Run this script if you want to experiment with MPI File Utils locally.
mkdir install
installdir=`pwd`/install

mkdir deps
cd deps
  wget https://github.com/hpc/libcircle/releases/download/v0.3/libcircle-0.3.0.tar.gz
  wget https://github.com/llnl/lwgrp/releases/download/v1.0.3/lwgrp-1.0.3.tar.gz
  wget https://github.com/llnl/dtcmp/releases/download/v1.1.1/dtcmp-1.1.1.tar.gz
  wget https://github.com/libarchive/libarchive/releases/download/3.5.1/libarchive-3.5.1.tar.gz

  tar -zxf libcircle-0.3.0.tar.gz
  cd libcircle-0.3.0
    ./configure --prefix=$installdir
    make install
  cd ..

  tar -zxf lwgrp-1.0.3.tar.gz
  cd lwgrp-1.0.3
    ./configure --prefix=$installdir
    make install
  cd ..

  tar -zxf dtcmp-1.1.1.tar.gz
  cd dtcmp-1.1.1
    ./configure --prefix=$installdir --with-lwgrp=$installdir
    make install
  cd ..

  tar -zxf libarchive-3.5.1.tar.gz
  cd libarchive-3.5.1
    ./configure --prefix=$installdir
    make install
  cd ..
cd ..


git clone --depth 1 https://github.com/hpc/mpifileutils
mkdir build install
cd build
cmake ../mpifileutils \
  -DWITH_DTCMP_PREFIX=../install \
  -DWITH_LibCircle_PREFIX=../install \
  -DCMAKE_INSTALL_PREFIX=../install
make install