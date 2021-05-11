#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// path to the n5
params.n5Path = ""

// path to the dataset containing s0
params.datasetPath = "/"

// downsampling factors for each dimension
params.downsamplingFactors = "2,2,2"

// pixel resolution for each dimension
params.pixelRes = "2,2,2"

// units for pixelRes
params.pixelResUnits = "nm"

// config for running single process
params.mem_gb = 32
params.cpus = 10

// config for running on cluster
params.numWorkers = 0


process n5_multiscale {
    container "janeliascicomp/n5-tools-py:1.0.1"

    memory { params.mem_gb }
    cpus { params.cpus }

    input:
    tuple val(n5Path), val(datasetPath), val(downsamplingFactors), val(pixelRes), val(pixelResUnits)

    output:
    val(n5Path)
    
    script:
    """
    /entrypoint.sh n5_multiscale -i $n5Path -d $datasetPath -f $downsamplingFactors -p $pixelRes -u $pixelResUnits
    """
}

process n5_multiscale_cluster {
    container "janeliascicomp/n5-tools-py:1.0.1"

    input:
    tuple val(n5Path), val(datasetPath), val(downsamplingFactors), val(pixelRes), val(pixelResUnits), val(numWorkers)

    output:
    val(n5Path)

    script:
    """
    /entrypoint.sh n5_multiscale -i $n5Path -d $datasetPath -f $downsamplingFactors -p $pixelRes -u $pixelResUnits \
        --distributed --workers $numWorkers --dashboard
    """
}

workflow {
    if (params.numWorkers>0) {
        n5_multiscale_cluster([params.n5Path, params.datasetPath, params.downsamplingFactors, params.pixelRes, params.pixelResUnits, params.numWorkers])
    }
    else {
        n5_multiscale([params.n5Path, params.datasetPath, params.downsamplingFactors, params.pixelRes, params.pixelResUnits])
    }
}

