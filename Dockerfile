# Copyright 2021-2023 Hewlett Packard Enterprise Development LP
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

FROM mpioperator/openmpi-builder:0.4.0 AS builder

RUN apt-get update && apt-get install -y \
    ca-certificates \
    wget tar make gcc cmake perl libbz2-dev pkg-config openssl libssl-dev libcap-dev \
    git libattr1-dev \
    openmpi-bin openssh-server openssh-client  \
    && rm -rf /var/lib/apt/lists/*

# Build and install MPI File Utils and all dependencies
RUN mkdir -p /deps /mfu
WORKDIR /deps

RUN wget https://github.com/hpc/libcircle/releases/download/v0.3/libcircle-0.3.0.tar.gz \
    && tar xfz libcircle-0.3.0.tar.gz \
    && cd libcircle-0.3.0 \
    && ./configure --prefix=/deps/libcircle/lib \
    && make install

RUN wget https://github.com/libarchive/libarchive/releases/download/v3.5.3/libarchive-3.5.3.tar.gz \
    && tar xfz libarchive-3.5.3.tar.gz \
    && cd libarchive-3.5.3 \
    && ./configure --prefix=/deps/libarchive/lib \
    && make install

RUN wget https://github.com/llnl/lwgrp/releases/download/v1.0.3/lwgrp-1.0.3.tar.gz \
    && tar xfz lwgrp-1.0.3.tar.gz \
    && cd lwgrp-1.0.3 \
    && ./configure --prefix=/deps/lwgrp/lib \
    && make install

RUN wget https://github.com/llnl/dtcmp/releases/download/v1.1.1/dtcmp-1.1.1.tar.gz \
    && tar xfz dtcmp-1.1.1.tar.gz \
    && cd dtcmp-1.1.1 \
    && ./configure --prefix=/deps/dtcmp/lib --with-lwgrp=/deps/lwgrp/lib \
    && make install

# Until a new release of mpifileutils is cut, we need to use a tagged commit on
# our fork to include our dcp changes (i.e. --uid, --gid)
RUN git clone --depth 1 https://github.com/nearnodeflash/mpifileutils.git --branch mknod-debug \
    && cd mpifileutils && git checkout dffac3103974378041a25f6a5d8c9c30cfe1db00 && cd .. \
    && mkdir build \
    && cd build \
    && cmake ../mpifileutils \
    -DWITH_LibCircle_PREFIX=/deps/libcircle/lib \
    -DWITH_DTCMP_PREFIX=/deps/dtcmp/lib \
    -DWITH_LibArchive_PREFIX=/deps/libarchive/lib \
    -DCMAKE_INSTALL_PREFIX=/mfu \
    && make install


# Build mfu with debugging symbols
FROM builder AS builder-debug

WORKDIR /deps
RUN cd build \
    && cmake ../mpifileutils \
    -DWITH_LibCircle_PREFIX=/deps/libcircle/lib \
    -DWITH_DTCMP_PREFIX=/deps/dtcmp/lib \
    -DWITH_LibArchive_PREFIX=/deps/libarchive/lib \
    -DCMAKE_INSTALL_PREFIX=/mfu \
    -DCMAKE_BUILD_TYPE=Debug \
    && make install


RUN wget https://download.open-mpi.org/release/open-mpi/v4.1/openmpi-4.1.0.tar.gz \
    && gunzip -c openmpi-4.1.0.tar.gz | tar xf - \
    && cd openmpi-4.1.0 \
    && ./configure --prefix=/opt/openmpi-4.1.0-debug --enable-debug \
    && make all install

###############################################################################
FROM mpioperator/openmpi:0.4.0 as production

# Provides nslookup for NNF Containers. Used for MPI Launcher InitContainers.
RUN apt-get update && apt-get install -y dnsutils && rm -rf /var/lib/apt/lists/*

COPY --from=builder /deps/libcircle/lib/ /usr
COPY --from=builder /deps/libarchive/lib/ /usr
COPY --from=builder /deps/lwgrp/lib/ /usr
COPY --from=builder /deps/dtcmp/lib/ /usr

COPY --from=builder /mfu/ /usr

###############################################################################
# Pull in the debugging symbols on top of production image
FROM production AS debug

# Override the production version of MFU with debug
COPY --from=builder-debug /mfu/ /usr

# Override the production version of openmpi with debug
# Remove installed version of openmpi
RUN apt-get remove -y openmpi-bin
COPY --from=builder-debug /opt/openmpi-4.1.0-debug/ /usr

# Install gdb and debugging tools
RUN apt-get update && apt-get install -y \
    gdb \
    file \
    && rm -rf /var/lib/apt/lists/*

# Verify both versions have debug symbols
RUN file /usr/bin/orterun | grep "with debug_info"
RUN file /usr/bin/dcp | grep "with debug_info"
