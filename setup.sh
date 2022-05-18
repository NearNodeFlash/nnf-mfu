#!/bin/bash

# Copyright 2021, 2022 Hewlett Packard Enterprise Development LP
# Other additional copyright holders may be indicated within.
#
# The entirety of this work is licensed under the Apache License,
# Version 2.0 (the "License"); you may not use this file except
# in compliance with the License.
#
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

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