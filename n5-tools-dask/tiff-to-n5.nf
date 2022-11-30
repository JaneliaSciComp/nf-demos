#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// path to the TIFF series
params.inputPath = ""

// path to the output n5
params.outputPath = ""

// path to the output dataset
params.outputDataset = "/s0"

// chunk size for n5
params.blockSize = "512,512,512"

// config for running single process
params.mem_gb = 1
params.cpus = 1

// config for starting a dask cluster
params.with_dask_cluster = false

include {
    dask_params;
} from '../params/dask_params';

dask_cluster_params = dask_params() + params

include {
    CREATE_DASK_CLUSTER;
} from '../external-modules/dask/workflows/create_dask_cluster' addParams(dask_cluster_params)

include {
    DASK_CLUSTER_TERMINATE;
} from '../external-modules/dask/modules/dask/cluster_terminate/main' addParams(dask_cluster_params)

include { get_runtime_opts } from '../utils' 

process tiff_to_n5 {
    container { dask_cluster_params.container }
    containerOptions { get_runtime_opts([inputPath, file(outputPath).parent]) }

    memory { "${params.mem_gb} GB" }
    cpus { params.cpus }

    input:
    tuple val(inputPath), val(outputPath), val(outputDataset), val(blockSize), val(scheduler), val(scheduler_workdir)

    output:
    tuple val(outputPath), val(outputDataset), val(scheduler), val(scheduler_workdir)
    
    script:
    def scheduler_arg = scheduler
        ? "--dask-scheduler ${scheduler}"
        : ''
    """
    /entrypoint.sh tif_to_n5 \
        -i $inputPath \
        -o $outputPath -d $outputDataset -c $blockSize \
        ${scheduler_arg}
    """
}
workflow {
    start_cluster
    | map {
        def (cluster_id, scheduler_ip, cluster_work_dir, connected_workers) = it
        [
            file(params.inputPath),
            file(params.outputPath),
            params.outputDataset,
            params.blockSize,
            scheduler_ip,
            cluster_work_dir,
        ]
    }
    | tiff_to_n5
    | groupTuple(by: [2,3]) // group all processes that run on the same cluster
    | map { 
        def (output_paths, output_datasets, scheduler_address, cluster_work_dir) = it
        return cluster_work_dir
    }
    | stop_cluster
}

workflow start_cluster {
    main:
    if (params.with_dask_cluster) {
        cluster = CREATE_DASK_CLUSTER(file(params.work_dir), [file(params.inputPath), file(params.outputPath)])
    } else {
        cluster = Channel.of(['', '', params.work_dir, -1])
    }

    emit:
    cluster
}

workflow stop_cluster {
    take:
    work_dir

    main:
    if (params.with_dask_cluster) {
        done = DASK_CLUSTER_TERMINATE(work_dir)
    } else {
        done = work_dir
    }

    emit:
    work_dir
}
