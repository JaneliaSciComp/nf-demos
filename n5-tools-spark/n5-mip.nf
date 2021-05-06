#!/usr/bin/env nextflow
// This pipeline generates max intensity projections in X/Y/Z directions and saves them as TIFF images 
// in the specified output folder.

nextflow.enable.dsl=2

// Path to the input N5 container
params.inputN5Path = ""

// Path to the input dataset within the N5 container
params.inputDatasetPath = "/s0"

// path to the output dataset
params.outputPath = ""

// MIP steps
params.mipStep = ""

// Compression for output MIP. Default is uncompressed. Supported compression types are (LZW)
params.compression = ""

// compute resources
params.mem_gb = 64
params.cpus = 20

outputPath = params.outputPath
if (!params.outputPath) {
    // Generate MIPs inside the N5 container by default
    outputPath = params.inputN5Path+"/mips"
    log.info "No --outputPath provided, MIPs will be generated in "+outputPath
}

process generateMIPs {
    container "janeliascicomp/n5-tools-java:1.0.0"

    memory { params.mem_gb+" GB" }
    cpus { params.cpus }

    input:
    tuple val(inputN5Path), val(inputDatasetPath), val(outputPath)
    val(mipStep)
    val(compression)

    output:
    val(outputPath)

    script:
    def args_list = []
    args_list << '-n' << inputN5Path
    args_list << '-i' << inputDatasetPath
    args_list << '-o' << outputPath
    if (mipStep) {
        args_list << '-m' << mipStep
    }
    if (compression) {
        args_list << '-c' << compression
    }
    def args = args_list.join(' ')
    """
    mkdir -p $outputPath
    /entrypoint.sh org.janelia.saalfeldlab.n5.spark.N5MaxIntensityProjectionSpark $args
    """
}

workflow {
    generateMIPs([params.inputN5Path, params.inputDatasetPath, outputPath],
        params.mipStep, params.compression)
}
