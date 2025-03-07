# Copyright 2021-2025 Hewlett Packard Enterprise Development LP
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

# These ARGs must be before the first FROM. This allows them to be valid for
# use in FROM instructions.
ARG MPI_OPERATOR_VERSION=0.6.0
# See https://www.open-mpi.org/software/ompi/v4.1/ for releases and their checksums.
ARG OPENMPI_VERSION=4.1.7
ARG OPENMPI_MD5=787d2bc8b3db336db97c34236934b3df
# Default to the latest cray 2.15 release
ARG LUSTRE_VERSION=cray-2.15.B19

FROM mpioperator/openmpi-builder:v$MPI_OPERATOR_VERSION AS builder

ARG OPENMPI_VERSION
ARG OPENMPI_MD5
ARG LUSTRE_VERSION
ENV OPENMPI_VERSION=$OPENMPI_VERSION
ENV OPENMPI_MD5=$OPENMPI_MD5
ENV LUSTRE_VERSION=$LUSTRE_VERSION

RUN apt-get update && apt-get install -y \
    ca-certificates \
    wget tar make gcc cmake perl libbz2-dev pkg-config openssl libssl-dev libcap-dev \
    git libattr1-dev \
    openssh-server openssh-client  \
    linux-headers-generic \
    libtool libyaml-dev ed libreadline-dev libsnmp-dev mpi-default-dev libselinux-dev libncurses5-dev libncurses-dev \
    bison flex gnupg libelf-dev gcc libssl-dev bc wget bzip2 build-essential udev kmod cpio module-assistant \
    libmount-dev libnl-genl-3-dev \
    && rm -rf /var/lib/apt/lists/* \
    && update-ca-certificates

# Build lustre to include in mpifileutils
COPY build_lustre.sh /build_lustre.sh
RUN /build_lustre.sh ${LUSTRE_VERSION}

# Create MPI File Utils dependencies directory
RUN mkdir -p /deps /mfu
WORKDIR /deps

# Stash the lustre libraries to make it easier to copy out in later stages
RUN mkdir -p /deps/lustre/lib \
    && cp -r /usr/lib/*lustre* /deps/lustre/lib/

# Remove the OS binary of openmpi and build from source
RUN apt-get remove -y openmpi-bin
RUN wget --no-check-certificate https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-$OPENMPI_VERSION.tar.gz
RUN [ $(md5sum openmpi-$OPENMPI_VERSION.tar.gz | awk '{print $1}') = "$OPENMPI_MD5" ]
RUN gunzip -c openmpi-$OPENMPI_VERSION.tar.gz | tar xf - \
    && cd openmpi-$OPENMPI_VERSION \
    && ./configure --prefix=/opt/openmpi-$OPENMPI_VERSION \
    && make -j $(nproc) all \
    && make install
RUN cp -r /opt/openmpi-$OPENMPI_VERSION/* /usr

# Build and install MPI File Utils and all dependencies
RUN wget https://github.com/hpc/libcircle/releases/download/v0.3/libcircle-0.3.0.tar.gz \
    && tar xfz libcircle-0.3.0.tar.gz \
    && cd libcircle-0.3.0 \
    && ./configure --prefix=/deps/libcircle/lib \
    && make -j $(nproc) install

RUN wget https://github.com/libarchive/libarchive/releases/download/v3.7.7/libarchive-3.7.7.tar.gz \
    && tar xfz libarchive-3.7.7.tar.gz \
    && cd libarchive-3.7.7 \
    && ./configure --prefix=/deps/libarchive/lib \
    && make -j $(nproc) install

RUN wget https://github.com/llnl/lwgrp/releases/download/v1.0.6/lwgrp-1.0.6.tar.gz \
    && tar xfz lwgrp-1.0.6.tar.gz \
    && cd lwgrp-1.0.6 \
    && ./configure --prefix=/deps/lwgrp/lib \
    && make -j $(nproc) install

RUN wget https://github.com/llnl/dtcmp/releases/download/v1.1.5/dtcmp-1.1.5.tar.gz \
    && tar xfz dtcmp-1.1.5.tar.gz \
    && cd dtcmp-1.1.5 \
    && ./configure --prefix=/deps/dtcmp/lib --with-lwgrp=/deps/lwgrp/lib \
    && make -j $(nproc) install

RUN git clone --depth 1 https://github.com/hpc/mpifileutils.git --branch v0.12 \
    && mkdir build \
    && cd build \
    && cmake ../mpifileutils \
    -DWITH_LibCircle_PREFIX=/deps/libcircle/lib \
    -DWITH_DTCMP_PREFIX=/deps/dtcmp/lib \
    -DWITH_LibArchive_PREFIX=/deps/libarchive/lib \
    -DCMAKE_INSTALL_PREFIX=/mfu \
    -DENABLE_LUSTRE=ON \
    && make install


# Build mfu with debugging symbols
FROM builder AS builder-debug

ARG OPENMPI_VERSION
ARG OPENMPI_MD5
ENV OPENMPI_VERSION=$OPENMPI_VERSION
ENV OPENMPI_MD5=$OPENMPI_MD5

WORKDIR /deps
RUN cd build \
    && cmake ../mpifileutils \
    -DWITH_LibCircle_PREFIX=/deps/libcircle/lib \
    -DWITH_DTCMP_PREFIX=/deps/dtcmp/lib \
    -DWITH_LibArchive_PREFIX=/deps/libarchive/lib \
    -DCMAKE_INSTALL_PREFIX=/mfu \
    -DENABLE_LUSTRE=ON \
    -DCMAKE_BUILD_TYPE=Debug \
    && make install


RUN wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-$OPENMPI_VERSION.tar.gz
RUN [ $(md5sum openmpi-$OPENMPI_VERSION.tar.gz | awk '{print $1}') = "$OPENMPI_MD5" ]
RUN gunzip -c openmpi-$OPENMPI_VERSION.tar.gz | tar xf - \
    && cd openmpi-$OPENMPI_VERSION \
    && ./configure --prefix=/opt/openmpi-$OPENMPI_VERSION-debug --enable-debug \
    && make -j $(nproc) all \
    && make install

###############################################################################
FROM mpioperator/openmpi:v$MPI_OPERATOR_VERSION AS production

ARG OPENMPI_VERSION
ENV OPENMPI_VERSION=$OPENMPI_VERSION

# Provides nslookup for NNF Containers. Used for MPI Launcher InitContainers.
RUN apt-get update && apt-get install -y dnsutils && rm -rf /var/lib/apt/lists/*

COPY --from=builder /deps/libcircle/lib/ /usr
COPY --from=builder /deps/libarchive/lib/ /usr
COPY --from=builder /deps/lwgrp/lib/ /usr
COPY --from=builder /deps/dtcmp/lib/ /usr

COPY --from=builder /deps/lustre/lib/ /usr/lib

COPY --from=builder /mfu/ /usr

RUN apt-get remove -y openmpi-bin
COPY --from=builder /opt/openmpi-$OPENMPI_VERSION /opt/openmpi-$OPENMPI_VERSION
RUN cp -r /opt/openmpi-$OPENMPI_VERSION/* /usr && rm -rf /openmpi*

# libreadline8 is necessary for dcp with lustre support
RUN apt-get update && apt-get install -y \
    libreadline8 \
    && rm -rf /var/lib/apt/lists/*

# Remove timezone configuration so we can inherit from host
RUN rm -rf /etc/timezone && rm -rf /etc/localtime

# Increase the number of allowed incomming ssh connections to support many mpirun applications
# attempting to hit a mpi host/worker (i.e. rabbit node) all at once. A compute node has 192 cores,
# and each rabbit has 16 compute nodes. This means 3072 (192*16) ssh connections could come in at
# once.  Round to the nearest power of 2 for good measure.
RUN sed -i "s/[ #]\(.*MaxSessions\).*/\1 4096/g" /etc/ssh/sshd_config \
    && sed -i "s/[ #]\(.*MaxStartups\).*/\1 4096/g" /etc/ssh/sshd_config

###############################################################################
# Pull in the debugging symbols on top of production image
FROM production AS debug

ARG OPENMPI_VERSION
ENV OPENMPI_VERSION=$OPENMPI_VERSION

# Override the production version of MFU with debug
COPY --from=builder-debug /mfu/ /usr

# Override the production version of openmpi with debug
# Remove installed version of openmpi
RUN apt-get remove -y openmpi-bin
COPY --from=builder-debug /opt/openmpi-$OPENMPI_VERSION-debug/ /opt/openmpi-$OPENMPI_VERSION-debug/
RUN cp -r /opt/openmpi-$OPENMPI_VERSION-debug/* /usr && rm -rf /openmpi*

# Install gdb and debugging tools
RUN apt-get update && apt-get install -y \
    gdb \
    file \
    && rm -rf /var/lib/apt/lists/*

# Verify both versions have debug symbols
RUN file /usr/bin/orterun | grep "with debug_info"
RUN file /usr/bin/dcp | grep "with debug_info"
