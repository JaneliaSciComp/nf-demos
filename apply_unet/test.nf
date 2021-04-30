#!/usr/bin/env nextflow

nextflow.enable.dsl=2


process tif_to_n5 {
    cpus 3

    input:
    val(input_tif_dir)
    val(output_dir)

    output:
    val(n5_dir)

    script:
    n5_dir = "$output_dir/export.n5"
    """
    $PWD/tif_to_n5.sh $input_tif_dir $n5_dir
    """
}

process unet {
    cpus 4
    label 'withGPU'

    input:
    val(input_n5)
    val(output_dir)

    output:
    val(n5_dir)

    script:
    n5_dir = "$output_dir/predict.n5"
    """
    $PWD/apply_unet.sh $input_n5 $n5_dir
    """
}

workflow apply_unet_to_tif {

    take:
    input_tif_dir
    output_dir

    main:
    export = tif_to_n5(input_tif_dir,
                  output_dir)
    predict = unet(export, output_dir)

    emit:
    predict
}

workflow {
    apply_unet_to_tif("$PWD", "$PWD")
}

