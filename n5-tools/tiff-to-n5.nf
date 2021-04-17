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

// n5 compression (RAW, GZIP, BZIP2, LZ4, XZ)
params.compression = "GZIP"

// compute resources
params.mem_gb = 32
params.cpus = 10

process tif_to_n5 {
    container "janeliascicomp/n5-tools-java:1.0.0"

    memory { params.mem_gb }
    cpus { params.cpus }

    input:
    tuple val(inputDirPath), val(outputN5Path), val(outputDatasetPath)
    val(blockSize)
    val(compression)

    output:
    tuple val(outputN5Path), val(outputDatasetPath)

    script:

    def args_list = []
    args_list << '-i' << inputDirPath
    args_list << '-n' << outputN5Path
    args_list << '-o' << outputDatasetPath
    if (blockSize) {
        args_list << '-b' << blockSize
    }
    if (compression) {
        args_list << '-c' << compression
    }
    def args = args_list.join(' ')
    """
    /entrypoint.sh org.janelia.saalfeldlab.n5.spark.SliceTiffToN5Spark $args
    """
}

workflow {
    tif_to_n5([params.inputDirPath, params.outputN5Path, params.outputDatasetPath], params.blockSize, params.compression)
}
