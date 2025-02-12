#!/bin/bash

set -ex

if [[ $1 == "" ]]; then
    echo "Usage: $0 <Cray lustre tag e.g. cray-2.15.B19>"
    exit 1
fi
CRAY_LUSTRE_VERSION=$1

# Determine kernel version and set variables
ls -l /usr/src/
KERNEL_FLAVOR=$(ls /lib/modules | head -1 | tr '-' '\n' | tail -1)
KERNEL_BASE_VER=$(ls /lib/modules | head -1 | grep -oP '\d+\.\d+\.\d+-\d+')
LINUX_DIR=$(ls -d -1 /usr/src/linux-headers-"${KERNEL_BASE_VER}-${KERNEL_FLAVOR}")

git clone --depth=1 https://github.com/Cray/lustre.git
cd lustre
git checkout "$CRAY_LUSTRE_VERSION"
sh autogen.sh
./configure --disable-server --enable-client --disable-tests --enable-mpitests=no \
    --disable-gss-keyring --enable-gss=no \
    --with-linux="${LINUX_DIR}"
make -j "$(nproc || true)"
make install
