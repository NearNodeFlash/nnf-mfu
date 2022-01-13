FROM arti.dev.cray.com/baseos-docker-master-local/centos8:centos8 AS builder
RUN dnf install -y wget tar make gcc gcc-c++ cmake perl bzip2-devel openssl-devel openssh-clients openssh-server

ARG OPENMPI_MAJOR_VERSION="4.1"
ARG OPENMPI_MINOR_VERSION="2"

RUN mkdir -p /tmp/openmpi
WORKDIR /tmp/openmpi
RUN wget https://download.open-mpi.org/release/open-mpi/v${OPENMPI_MAJOR_VERSION}/openmpi-${OPENMPI_MAJOR_VERSION}.${OPENMPI_MINOR_VERSION}.tar.gz \
    && tar xfz openmpi-${OPENMPI_MAJOR_VERSION}.${OPENMPI_MINOR_VERSION}.tar.gz \
    && cd openmpi-${OPENMPI_MAJOR_VERSION}.${OPENMPI_MINOR_VERSION} \
    && ./configure \
    && make && make install \
    && rm -rf /tmp/openmpi

RUN mkdir -p /deps 
WORKDIR /deps

RUN wget https://github.com/hpc/libcircle/releases/download/v0.3/libcircle-0.3.0.tar.gz \
    && tar xfz libcircle-0.3.0.tar.gz \
    && cd libcircle-0.3.0 \
    && ./configure --prefix=/usr/local \
    && make install

RUN wget https://github.com/llnl/lwgrp/releases/download/v1.0.3/lwgrp-1.0.3.tar.gz \
    && tar xfz lwgrp-1.0.3.tar.gz \
    && cd lwgrp-1.0.3 \
    && ./configure --prefix=/usr/local \
    && make install

RUN wget https://github.com/llnl/dtcmp/releases/download/v1.1.1/dtcmp-1.1.1.tar.gz \
    && tar xfz dtcmp-1.1.1.tar.gz \
    && cd dtcmp-1.1.1 \
    && ./configure --prefix=/usr/local --with-lwgrp=/usr/local \
    && make install

RUN wget https://github.com/libarchive/libarchive/releases/download/3.5.1/libarchive-3.5.1.tar.gz \
    && tar xfz libarchive-3.5.1.tar.gz \
    && cd libarchive-3.5.1 \
    && ./configure --prefix=/usr/local \
    && make install
 
ARG MPI_FILE_UTILS_VERSION="0.11"
RUN wget https://github.com/hpc/mpifileutils/archive/v${MPI_FILE_UTILS_VERSION}.tar.gz \
    && tar xfz v${MPI_FILE_UTILS_VERSION}.tar.gz \
    && mkdir build \
    && cd build \
    && cmake ../mpifileutils-${MPI_FILE_UTILS_VERSION} -DWITH_DTCMP_PREFIX=/usr/local -DWITH_LibCircle_PREFIX=/usr/local -DCMAKE_INSTALL_PREFIX=/usr \
    && make install

RUN rm -rf /deps
