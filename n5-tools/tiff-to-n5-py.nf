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

// config for running single process
params.mem_gb = 32
params.cpus = 10

// config for running on cluster
params.numWorkers = 0

process tif_to_n5 {
    container "janeliascicomp/n5-tools-py:1.0.0"

    memory { params.mem_gb }
    cpus { params.cpus }

    input:
    tuple val(inputDirPath), val(outputN5Path), val(outputDatasetPath), val(blockSize)

    output:
    tuple val(outputN5Path), val(outputDatasetPath)
    
    script:
    """
    /entrypoint.sh tif_to_n5 -i $inputDirPath -o $outputN5Path -d $outputDatasetPath -c $blockSize
    """
}

process tif_to_n5_cluster {
    container "janeliascicomp/n5-tools-py:1.0.0"

    input:
    tuple val(inputDirPath), val(outputN5Path), val(outputDatasetPath), val(blockSize), val(numWorkers)

    output:
    tuple val(outputN5Path), val(outputDatasetPath)

    script:
    """
    /entrypoint.sh tif_to_n5 -i $inputDirPath -o $outputN5Path -d $outputDatasetPath -c $blockSize \
        --distributed --workers $numWorkers --dashboard
    """
}

workflow {
    if (params.numWorkers>0) {
        tif_to_n5_cluster([params.inputDirPath, params.outputN5Path, params.outputDatasetPath, params.blockSize, params.numWorkers])
    }
    else {
        tif_to_n5([params.inputDirPath, params.outputN5Path, params.outputDatasetPath, params.blockSize])
    }
}
