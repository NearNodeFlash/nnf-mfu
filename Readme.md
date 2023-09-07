# Near Node Flash - MPI File Utils (MFU)

This repository houses the Dockerfile responsible for generating an [Open
MPI](https://www.open-mpi.org) image with the capability to execute [MPI File
Utils](https://github.com/hpc/mpifileutils) commands.

The foundation of this image relies on
[mpi-operator](https://github.com/kubeflow/mpi-operator) with the addition of
MPI File Utils that have been constructed from source. At the time of this writing, the mpi-operator image installs v4.1.0 of Open MPI.

This image is primarily used for NNF Data Movement and as a base image for running NNF User Containers.

Within this repository, you will find two distinct versions of the image:
production and debug. The production image is the primary version, encompassing
the features described above. The debug image incorporates
versions of OpenMPI and MPI File Utils that have been compiled with debugging
symbols. This particular image is useful for debugging and has been constructed for the use of analyzing coredumps.
