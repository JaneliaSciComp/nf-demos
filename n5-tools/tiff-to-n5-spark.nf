#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// Java main class
main_class = "org.janelia.saalfeldlab.n5.spark.SliceTiffToN5Spark"

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

// config for running single process
params.mem_gb = 32
params.cpus = 10

// config for running on spark cluster
params.spark_container_repo = "janeliascicomp"
params.spark_container_name = "n5-tools-spark"
params.spark_container_version = "1.0.0"
params.spark_local_dir = "/tmp"
params.spark_work_dir = "$PWD/work/spark"
params.spark_workers = 0
params.spark_worker_cores = 4
params.spark_gb_per_core = 4
params.spark_executor_cores = 1
params.spark_driver_cores = 2

include {
    run_spark_app
} from '../external-modules/spark/lib/workflows' 

def get_arg_string(inputDirPath, outputN5Path, outputDatasetPath, blockSize, compression) {
    def args_list = []
    args_list << '-i' << params.inputDirPath
    args_list << '-n' << params.outputN5Path
    args_list << '-o' << params.outputDatasetPath
    if (params.blockSize) {
        args_list << '-b' << params.blockSize
    }
    if (params.compression) {
        args_list << '-c' << params.compression
    }
    return args_list.join(' ')
}

workflow tif_to_n5_cluster {
    take:
    app_args
    spark_work_dir
    spark_workers
    spark_worker_cores
    spark_executor_cores
    spark_gb_per_core
    spark_driver_cores

    main:
    def arg_strings = app_args.map { 
        (inputDirPath, outputN5Path, outputDatasetPath, blockSize, compression) = it
        get_arg_string(inputDirPath, outputN5Path, outputDatasetPath, blockSize, compression)
    }
    run_spark_app(
        "/app/app.jar",
        main_class,
        arg_strings,
        'tiff-to-n5.log','terminate-stitching','',
        spark_work_dir,
        spark_workers,
        spark_worker_cores,
        spark_executor_cores,
        spark_gb_per_core,
        spark_driver_cores,
        '1g','128m','','client'
    )
}

process tif_to_n5 {
    container "janeliascicomp/n5-tools-java:1.0.0"

    memory { params.mem_gb }
    cpus { params.cpus }

    input:
    tuple val(inputDirPath), val(outputN5Path), val(outputDatasetPath), val(blockSize), val(compression)

    output:
    tuple val(outputN5Path), val(outputDatasetPath)

    script:
    def args = get_arg_string(inputDirPath, outputN5Path, outputDatasetPath, blockSize, compression)
    """
    /entrypoint.sh $main_class $args
    """
}

workflow {
    args = [params.inputDirPath, params.outputN5Path, params.outputDatasetPath, params.blockSize, params.compression]
    if (params.spark_workers>0) {
        tif_to_n5_cluster(Channel.of(args), 
            params.spark_work_dir,
            params.spark_workers,
            params.spark_worker_cores,
            params.spark_executor_cores,
            params.spark_gb_per_core,
            params.spark_driver_cores)
    }
    else {
        tif_to_n5(args)
    }
}