#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Path to the input N5 container
params.inputN5Path = ""

// Path to the input dataset within the N5 container
params.inputDatasetPath = "/s0"

// path to the output dataset
params.outputN5Path = ""

// Path to the output dataset within the N5 container
params.outputDatasetPath = "/s0"

// Block size for the output dataset (by default the same block size is used as for the input dataset)
params.blockSize = ""

// Compression to be used for the converted dataset (by default the same compression is used as for the input dataset)
// Supported compression types are (RAW, GZIP, BZIP2, LZ4, XZ)
params.compression = ""

// Type to be used for the converted dataset (by default the same type is used as for the input dataset)
params.type = ""

// Minimum value of the input range to be used for the conversion (default is min type value for integer types, or 0 for real types)
params.minValue = ""

// Maximum value of the input range to be used for the conversion (default is max type value for integer types, or 1 for real types)
params.maxValue = ""

// Will overwrite existing output dataset if specified
params.force = ""

// compute resources
params.mem_gb = 32
params.cpus = 10

process resave {
    container "janeliascicomp/n5-tools-java:1.0.0"

    memory { params.mem_gb }
    cpus { params.cpus }

    input:
    tuple val(inputN5Path), val(inputDatasetPath), val(outputN5Path), val(outputDatasetPath)
    val(blockSize)
    val(compression)
    val(type)
    val(minValue)
    val(maxValue)
    val(force)

    output:
    tuple val(outputN5Path), val(inputDatasetPath)

    script:
    def args_list = []
    args_list << '-ni' << inputN5Path
    args_list << '-i' << inputDatasetPath
    args_list << '-no' << outputN5Path
    args_list << '-o' << outputDatasetPath
    if (blockSize) {
        args_list << '-b' << blockSize
    }
    if (compression) {
        args_list << '-c' << compression
    }
    if (type) {
        args_list << '-t' << type
    }
    if (minValue) {
        args_list << '-min' << minValue
    }
    if (maxValue) {
        args_list << '-max' << maxValue
    }
    if (args.force) {
        args_list << '-force'
    }
    def args = args_list.join(' ')
    """
    /entrypoint.sh org.janelia.saalfeldlab.n5.spark.N5ConvertSpark $args
    """
}
workflow {
    file(params.outputN5Path).mkdirs()
    resave([params.inputN5Path, params.inputDatasetPath, params.outputN5Path, params.outputDatasetPath],
        params.blockSize, params.compression, params.type, params.minValue, params.maxValue, params.force)
}
