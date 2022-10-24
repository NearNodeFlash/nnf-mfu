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

FROM mpioperator/openmpi-builder:0.3.0 AS builder

RUN apt update

RUN apt install -y --no-install-recommends \
    ca-certificates \
    wget tar make gcc cmake perl libbz2-dev pkg-config openssl libssl-dev libcap-dev

RUN apt install -y --no-install-recommends openmpi-bin openssh-server openssh-client  \
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

ARG MPI_FILE_UTILS_VERSION="0.11"
RUN wget https://github.com/hpc/mpifileutils/archive/v${MPI_FILE_UTILS_VERSION}.tar.gz \
    && tar xfz v${MPI_FILE_UTILS_VERSION}.tar.gz \
    && mkdir build \
    && cd build \
    && cmake ../mpifileutils-${MPI_FILE_UTILS_VERSION} \
        -DWITH_LibCircle_PREFIX=/deps/libcircle/lib \
        -DWITH_DTCMP_PREFIX=/deps/dtcmp/lib \
        -DWITH_LibArchive_PREFIX=/deps/libarchive/lib \
        -DCMAKE_INSTALL_PREFIX=/mfu \
    && make install

FROM mpioperator/openmpi:0.3.0

COPY --from=builder /deps/libcircle/lib/ /usr
COPY --from=builder /deps/libarchive/lib/ /usr
COPY --from=builder /deps/lwgrp/lib/ /usr
COPY --from=builder /deps/dtcmp/lib/ /usr

COPY --from=builder /mfu/ /usr