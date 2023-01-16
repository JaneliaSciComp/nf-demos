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

// downsampling factors for each dimension
params.downsamplingFactors = "2,2,2"

// pixel resolution for each dimension
params.pixelRes = "2,2,2"

// units for pixelRes
params.pixelResUnits = "nm"

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

include { tiff_to_n5 } from './tiff-to-n5' addParams(dask_cluster_params)
include { n5_multiscale } from './n5-multiscale' addParams(dask_cluster_params)

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
    | map {
        def (n5_path, n5_dataset, scheduler_ip, cluster_work_dir) = it
        [
            n5_path,
            "/",
            params.downsamplingFactors,
            params.pixelRes,
            params.pixelResUnits,
            scheduler_ip, cluster_work_dir,
        ]
    }
    | n5_multiscale
    | map {
        def (input_path, scheduler_ip, cluster_work_dir) = it
        return cluster_work_dir
    }
    | stop_cluster
}

workflow start_cluster {
    main:
    if (params.with_dask_cluster) {
        cluster = CREATE_DASK_CLUSTER(file(params.work_dir), 
                                      Channel.of([file(params.inputPath), file(params.outputPath).parent]))
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
