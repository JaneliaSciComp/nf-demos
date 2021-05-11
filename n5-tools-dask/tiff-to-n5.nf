#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// path to the TIFF series
params.inputPath = ""

// path to the output n5
params.outputPath = ""

// path to the output dataset
params.outputDataset = "/s0"

// chunk size for n5
params.blockSize = "512,512,512"

// config for running single process
params.mem_gb = 32
params.cpus = 10

// config for running on cluster
params.numWorkers = 0

include { getOptions } from '../utils' 

process tif_to_n5 {
    container "janeliascicomp/n5-tools-py:1.0.1"
    containerOptions { getOptions([inputPath, outputPath]) }

    memory { "${params.mem_gb} GB" }
    cpus { params.cpus }

    input:
    tuple val(inputPath), val(outputPath), val(outputDataset), val(blockSize)

    output:
    tuple val(outputPath), val(outputDataset)
    
    script:
    """
    /entrypoint.sh tif_to_n5 -i $inputPath -o $outputPath -d $outputDataset -c $blockSize
    """
}

process tif_to_n5_cluster {
    container "janeliascicomp/n5-tools-py:1.0.0"
    containerOptions { getOptions([inputPath, outputPath]) }

    memory { "${params.mem_gb} GB" }
    cpus { params.cpus }
    
    input:
    tuple val(inputPath), val(outputPath), val(outputDataset), val(blockSize), val(numWorkers)

    output:
    tuple val(outputPath), val(outputDataset)

    script:
    """
    /entrypoint.sh tif_to_n5 -i $inputPath -o $outputPath -d $outputDataset -c $blockSize \
        --distributed --workers $numWorkers --dashboard
    """
}

workflow {
    if (params.numWorkers>0) {
        tif_to_n5_cluster([params.inputPath, params.outputPath, params.outputDataset, params.blockSize, params.numWorkers])
    }
    else {
        tif_to_n5([params.inputPath, params.outputPath, params.outputDataset, params.blockSize])
    }
}
