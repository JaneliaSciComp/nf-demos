#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// path or url to the TIFF series
params.input_path = ""

// path or url to the output n5
params.outdir = ""

// chunk size for n5
params.chunk_size = "512,512,512"

input_path = file(params.input_path)
outdir = file(params.outdir)
chunk_size = params.chunk_size

process convert_tif_to_n5 {
    container "janeliascicomp/n5-tools-py:1.0.0"
    publishDir outdir

    memory '64 GB'
    cpus 10

    input:
    file input_path
    file outdir
    val chunk_size

    output:
    file "output.n5"

    script:
    """
    /entrypoint.sh tif_to_n5 -i $input_path -o output.n5 -c $chunk_size --distributed
    """
}

workflow {
    convert_tif_to_n5(input_path, outdir, chunk_size)
}


workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

