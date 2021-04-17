#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// path to the TIFF series
params.inputDirPath = ""

// path to the output n5
params.outputN5Path = ""

// path to the output dataset
params.outputDatasetPath = "/s0"

// chunk size for n5
params.blockSize = "512,512,512"

// downsampling factors for each dimension
params.downsamplingFactors = "2,2,2"

// pixel resolution for each dimension
params.pixelRes = "2,2,2"

// units for pixelRes
params.pixelResUnits = "nm"

// config for running on cluster
params.numWorkers = 10

include {
    tif_to_n5_cluster
} from './tiff-to-n5-py' 

include {
    n5_multiscale_cluster
} from './n5-multiscale' 

workflow {
    if (params.numWorkers<1) {
        println "Provided --numWorkers must be greater than zero"
        exit 1
    }
    Channel.of([params.inputDirPath, params.outputN5Path, params.outputDatasetPath, params.blockSize, params.numWorkers])
        | tif_to_n5_cluster
        | map {
            (n5Path, _) = it
            [n5Path, "/", params.downsamplingFactors, params.pixelRes, params.pixelResUnits, params.numWorkers]
        }
        | n5_multiscale_cluster
}