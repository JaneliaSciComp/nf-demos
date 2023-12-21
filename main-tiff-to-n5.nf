include { OMETIFF_TO_N5 } from './modules/local/ometiff_to_n5/main'

include { START_DASK    } from './subworkflows/bits/start_dask/main'
include { STOP_DASK     } from './subworkflows/bits/stop_dask/main'

workflow {
    def input_path = file(params.input_path)
    def output_path = file(params.output_path)
    def input_name = input_path.name.split('\\.')[0]
    def meta = [id: input_name]

    def cluster_path_bindings = [ input_path, output_path ] +
        (params.dask_config 
            ? [ file(params.dask_config) ]
            : [])

    def dask_cluster_inputs = Channel.of(
        [
            meta,cluster_path_bindings,
        ],
    )

    def dask_cluster_info = START_DASK(
        dask_cluster_inputs,
        true,
        file(params.dask_work_dir),
        params.dask_workers,
        params.dask_required_workers,
        params.dask_worker_cpus,
        params.dask_worker_memgb,
    )

    dask_cluster_info.subscribe {
        log.info "Cluster info: $it"
    }

    def inputs = dask_cluster_info
    | combine(dask_cluster_inputs, by:0)
    | multiMap {
        def (cluster_meta, cluster_context, cluster_paths) = it
        def (t2n5_input_path, t2n5_output_path, dask_config_arg) = cluster_paths
        def dask_config_path = dask_config_arg ?: []
        def data = [
            cluster_meta,
            t2n5_input_path,
            t2n5_output_path,
            dask_config_path,
            params.output_name,
            params.scale_subpath,
        ]
        def cluster = [
            cluster_meta,
            cluster_context,
            cluster_context.scheduler_address ?: '' ,
        ]
        log.info "Prepare tiff to n5 inputs $it -> ${data}, ${cluster}"
        data: data
        cluster: cluster
    }

    def tiff_to_n5_res = OMETIFF_TO_N5(
        inputs.data, 
        inputs.cluster.map { it[-1] }, // dask scheduler address only
        params.tiff_to_n5_cpus,
        params.tiff_to_n5_memgb,
    )

    tiff_to_n5_res | view

    def terminated_cluster = dask_cluster_info
    | join(tiff_to_n5_res, by:0)
    | map {
        def (cluster_meta, cluster_context) = it
        [ cluster_meta, cluster_context ]
    }
    | STOP_DASK

    terminated_cluster.subscribe {
        log.info "Terminated cluster info: $it"
    }

}
