#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// path to the TIFF series
params.input_path = ""

// path to the output n5
params.output_path = ""

// chunk size for n5
params.chunk_size = "512,512,512"

input_path = file(params.input_path)
output_path = file(params.output_path)
chunk_size = params.chunk_size

process convert_tif_to_n5 {
    container "janeliascicomp/n5-tools-py:1.0.0"

    memory '64 GB'
    cpus 10

    input:
    file input_path
    file output_path
    val chunk_size

    script:
    """
    /entrypoint.sh tif_to_n5 -i $input_path -o $output_path -c $chunk_size --distributed
    """
}

workflow {
    convert_tif_to_n5(input_path, output_path, chunk_size)
}


workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

