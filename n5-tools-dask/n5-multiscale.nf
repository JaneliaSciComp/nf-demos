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
        ? "--scheduler ${scheduler}"
        : ''
    def n_workers_arg = dask_cluster_params.workers > 0
        ? "--workers ${dask_cluster_params.workers}"
        : ''
    """
    python app/n5_multiscale.py \
        -i $inputPath -d $dataset \
        -f $downsamplingFactors -p $pixelRes -u $pixelResUnits \
        ${n_workers_arg} \
        ${scheduler_arg}
    """
}

workflow {
    if (params.with_dask_cluster) {
        CREATE_DASK_CLUSTER(file(params.work_dir))
        | map {
            log.info "Use dask scheduler: ${it.scheduler_address} (${it.work_dir})"
            [
                params.inputPath,
                params.dataset,
                params.downsamplingFactors,
                params.pixelRes,
                params.pixelResUnits,
                it.scheduler_address,
                it.work_dir,
            ]
        }
        | n5_multiscale
        | groupTuple(by: [1,2])
        | map { 
            def (input_paths, scheduler_address, work_dir) = it
            return work_dir
        }
        | DASK_CLUSTER_TERMINATE
    } else {
        n5_multiscale(
            [
                params.inputPath,
                params.dataset,
                params.downsamplingFactors,
                params.pixelRes,
                params.pixelResUnits,
                '', // scheduler address
                '', // scheduler workdir
            ]
        )
     }
}
