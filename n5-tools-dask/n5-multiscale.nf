#!/usr/bin/env nextflow

nextflow.enable.dsl=2

// path to the n5
params.inputPath = ""

// path to the dataset containing s0
params.dataset = "/"

// downsampling factors for each dimension
params.downsamplingFactors = "2,2,2"

// pixel resolution for each dimension
params.pixelRes = "2,2,2"

// units for pixelRes
params.pixelResUnits = "nm"

// memory and cpus config - when not using a cluster these value should be larger
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

process n5_multiscale {
    container { dask_cluster_params.container }
    containerOptions { get_runtime_opts([inputPath]) }

    memory { "${params.mem_gb} GB" }
    cpus { params.cpus }

    input:
    tuple val(inputPath), val(dataset), val(downsamplingFactors), val(pixelRes), val(pixelResUnits), val(scheduler), val(scheduler_workdir)

    output:
    tuple val(inputPath), val(scheduler), val(scheduler_workdir)
    
    script:
    def scheduler_arg = scheduler
        ? "--dask-scheduler ${scheduler}"
        : ''
    """
    /entrypoint.sh n5_multiscale \
        -i $inputPath -d $dataset \
        -f $downsamplingFactors -p $pixelRes -u $pixelResUnits \
        ${scheduler_arg}
    """
}

workflow {
    start_cluster
    | map {
        def (cluster_id, scheduler_ip, cluster_work_dir, connected_workers) = it
        [
            file(params.inputPath),
            params.dataset,
            params.downsamplingFactors,
            params.pixelRes,
            params.pixelResUnits,
            scheduler_ip,
            cluster_work_dir,
        ]
    }
    | n5_multiscale
    | groupTuple(by: [1,2]) // group all processes that run on the same cluster
    | map { 
        def (input_paths, scheduler_ip, cluster_work_dir) = it
        return cluster_work_dir
    }
    | stop_cluster
}

workflow start_cluster {
    main:
    if (params.with_dask_cluster) {
        cluster = CREATE_DASK_CLUSTER(file(params.work_dir), [file(params.inputPath)])
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
