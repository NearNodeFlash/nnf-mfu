// Procedure for building NNF MPI File Utils (mfu)

@Library('dst-shared@master') _

// See https://github.hpe.com/hpe/hpc-dst-jenkins-shared-library for all
// the inputs to the dockerBuildPipeline.
// In particular: vars/dockerBuildPipeline.groovy
dockerBuildPipeline {
        repository = "cray"
        imagePrefix = "cray"
        app = "dp-nnf-mfu"
        name = "dp-nnf-mfu"
        description = "Near Node Flash MPI File Utils"
        dockerfile = "Dockerfile"
        autoJira = false
        createSDPManifest = false
        product = "rabsw"
}
