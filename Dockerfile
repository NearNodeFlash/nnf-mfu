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

FROM debian:buster

RUN apt update

RUN apt install -y --no-install-recommends \
    g++ \
    libopenmpi-dev \
    ca-certificates \
    wget tar make gcc cmake perl libbz2-dev pkg-config openssl libssl-dev libcap-dev

RUN apt install -y --no-install-recommends openmpi-bin openssh-server openssh-client  \
    && rm -rf /var/lib/apt/lists/*

# Build and install MPI File Utils and all dependencies

RUN mkdir -p /deps
WORKDIR /deps

RUN wget https://github.com/hpc/libcircle/releases/download/v0.3/libcircle-0.3.0.tar.gz \
    && tar xfz libcircle-0.3.0.tar.gz \
    && cd libcircle-0.3.0 \
    && ./configure --prefix=/usr/lib \
    && make install

RUN wget https://github.com/llnl/lwgrp/releases/download/v1.0.3/lwgrp-1.0.3.tar.gz \
    && tar xfz lwgrp-1.0.3.tar.gz \
    && cd lwgrp-1.0.3 \
    && ./configure --prefix=/usr/lib \
    && make install

RUN wget https://github.com/llnl/dtcmp/releases/download/v1.1.1/dtcmp-1.1.1.tar.gz \
    && tar xfz dtcmp-1.1.1.tar.gz \
    && cd dtcmp-1.1.1 \
    && ./configure --prefix=/usr/lib --with-lwgrp=/usr/lib \
    && make install

RUN wget https://github.com/libarchive/libarchive/releases/download/v3.5.3/libarchive-3.5.3.tar.gz \
    && tar xfz libarchive-3.5.3.tar.gz \
    && cd libarchive-3.5.3 \
    && ./configure --prefix=/usr/lib \
    && make install

ARG MPI_FILE_UTILS_VERSION="0.11"
RUN wget https://github.com/hpc/mpifileutils/archive/v${MPI_FILE_UTILS_VERSION}.tar.gz \
    && tar xfz v${MPI_FILE_UTILS_VERSION}.tar.gz \
    && mkdir build \
    && cd build \
    && cmake ../mpifileutils-${MPI_FILE_UTILS_VERSION} -DWITH_DTCMP_PREFIX=/usr/lib -DWITH_LibCircle_PREFIX=/usr/lib -DWITH_LibArchive_PREFIX=/usr/lib -DCMAKE_INSTALL_PREFIX=/usr \
    && make install

RUN rm -rf /deps

# The following several lines are from the mpi-operator base Dockerfile
# https://github.com/kubeflow/mpi-operator/blob/master/build/base/Dockerfile

ARG port=2222

# Add priviledge separation directoy to run sshd as root.
RUN mkdir -p /var/run/sshd
# Add capability to run sshd as non-root.
RUN setcap CAP_NET_BIND_SERVICE=+eip /usr/sbin/sshd

# Allow OpenSSH to talk to containers without asking for confirmation
# by disabling StrictHostKeyChecking.
# mpi-operator mounts the .ssh folder from a Secret. For that to work, we need
# to disable UserKnownHostsFile to avoid write permissions.
# Disabling StrictModes avoids directory and files read permission checks.
RUN sed -i "s/[ #]\(.*StrictHostKeyChecking \).*/ \1no/g" /etc/ssh/ssh_config \
    && echo "    UserKnownHostsFile /dev/null" >> /etc/ssh/ssh_config \
    && sed -i "s/[ #]\(.*Port \).*/ \1$port/g" /etc/ssh/ssh_config \
    && sed -i "s/#\(StrictModes \).*/\1no/g" /etc/ssh/sshd_config \
    && sed -i "s/#\(Port \).*/\1$port/g" /etc/ssh/sshd_config

RUN useradd -m mpiuser
WORKDIR /home/mpiuser
# Configurations for running sshd as non-root.
COPY --chown=mpiuser sshd_config .sshd_config
RUN echo "Port $port" >> /home/mpiuser/.sshd_config