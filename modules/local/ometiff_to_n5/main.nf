process OMETIFF_TO_N5 {
    container { task.ext.container ?: 'quay.io/bioimagetools/n5tools:1.0-dask2023.10.1-py11' }
    cpus { ncpus }
    memory "${mem_gb} GB"

    input:
    tuple val(meta),
          path(input_path),
          path(output_path),
          path(dask_config),
          val(output_name),
          val(scale_subpath)
    val(dask_scheduler)
    val(ncpus)
    val(mem_gb)

    output:
    tuple val(meta), path(input_path), env(output_fullpath)

    script:
    def args = task.ext.args ?: ''
    def dask_scheduler_arg = dask_scheduler ? "--dask-scheduler ${dask_scheduler}" : ''
    def dask_config_arg = dask_config ? "--dask-config ${dask_config}" : ''

    """
    output_fullpath=\$(readlink ${output_path})
    mkdir -p \${output_fullpath}

    python /app/ometif_to_n5.py \
        -i ${input_path} \
        -o ${output_path}/${output_name} -d ${scale_subpath} \
        ${dask_scheduler_arg} \
        ${dask_config_arg} \
        ${args}
    """
}
