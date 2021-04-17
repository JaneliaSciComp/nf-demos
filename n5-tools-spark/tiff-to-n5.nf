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

// config for running single process
params.mem_gb = 32
params.cpus = 10

// config for running on cluster
params.numWorkers = 0
params.spark_container_repo = "janeliascicomp"
params.spark_container_name = "n5-tools-spark"
params.spark_container_version = "1.0.0"
params.spark_local_dir = "/tmp"
params.spark_work_dir = "$PWD/work/spark"
params.spark_worker_cores = 4
params.spark_gb_per_core = 4
params.spark_executor_cores = 1

// Java main class
main_class = "org.janelia.saalfeldlab.n5.spark.SliceTiffToN5Spark"

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

process tif_to_n5 {
    container "janeliascicomp/n5-tools-java:1.0.0"

    memory { mem_gb }
    cpus { cpus }

    input:
    tuple val(inputDirPath), val(outputN5Path), val(outputDatasetPath), val(blockSize), val(compression), val(mem_gb), val(cpus)

    output:
    tuple val(outputN5Path), val(outputDatasetPath)

    script:
    def args = get_arg_string(inputDirPath, outputN5Path, outputDatasetPath, blockSize, compression)
    """
    /entrypoint.sh $main_class $args
    """
}

include {
    spark_cluster_start
    spark_cluster_stop
    run_spark_app_on_existing_cluster
} from '../external-modules/spark/lib/workflows' 

workflow tif_to_n5_cluster {
    take:
    app_args
    spark_uri
    spark_app_terminate_name
    spark_work_dir
    spark_workers
    spark_worker_cores
    spark_executor_cores
    spark_gbmem_per_core

    main:
    def spark_app_args = app_args.map { 
        (inputDirPath, outputN5Path, outputDatasetPath, blockSize, compression) = it
        get_arg_string(inputDirPath, outputN5Path, outputDatasetPath, blockSize, compression)
    }
    spark_app_res = run_spark_app_on_existing_cluster(
        spark_uri,
        "/app/app.jar",
        main_class,
        spark_app_args,
        'tiff-to-n5.log',
        spark_app_terminate_name,
        '',
        spark_work_dir,
        spark_workers,
        spark_executor_cores,
        spark_gbmem_per_core,
        2,
        '1g',
        '128m',
        '',
        'client'
    )

    emit:
    spark_app_res
}

workflow {
    if (params.numWorkers>0) {
        log.debug "Running with cluster of ${params.numWorkers} workers"
        def spark_app_terminate_name = 'terminate-stitching'
        // start the cluster
        def spark_cluster_res = spark_cluster_start(
            '',
            params.spark_work_dir,
            params.numWorkers,
            params.spark_worker_cores,
            params.spark_gb_per_core,
            spark_app_terminate_name
        )
        def my_app_args = [params.inputDirPath, params.outputN5Path, params.outputDatasetPath, params.blockSize, params.compression]
        // run the app on the cluster
        def spark_app_res = tif_to_n5_cluster(
            Channel.of(my_app_args), 
            spark_cluster_res | map { it[0] }, // select spark_uri from result
            spark_app_terminate_name,
            params.spark_work_dir,
            params.numWorkers,
            params.spark_worker_cores,
            params.spark_executor_cores,
            params.spark_gb_per_core)
        // stop the cluster
        done = spark_cluster_stop(
            spark_app_res.map { it[1] }, // select the working dir from the result
            spark_app_terminate_name
        )
    }
    else {
        log.debug "Running without cluster"
        def my_app_args = [
            params.inputDirPath, 
            params.outputN5Path, 
            params.outputDatasetPath, 
            params.blockSize, 
            params.compression, 
            params.mem_gb, 
            params.cpus
        ]
        tif_to_n5(my_app_args)
    }
}