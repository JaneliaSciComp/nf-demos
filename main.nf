#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// path or url to the TIFF series
params.input_path = ""

// path or url to the output n5
params.outdir = ""

// chunk size for n5
params.chunk_size = "512,512,512"

process convert_tif_to_n5 {
    container "janeliascicomp/n5-tools-py:1.0.0"
    publishDir "${params.outdir}", mode: 'copy'

    input:
    val(input_path)
    val(chunk_size)

    output:
    file "output.n5"

    script:
    """
    /entrypoint.sh tif_to_n5 -i $input_path -o output.n5 -c $chunk_size 
    #--distributed
    """

}

workflow {
    convert_tif_to_n5(params.input_path, params.chunk_size)
}


workflow.onComplete {
    println "Pipeline $workflow.scriptName completed at: $workflow.complete "
    println "Execution status: ${ workflow.success ? 'OK' : 'failed' }"
}

