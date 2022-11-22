def get_runtime_opts(paths) {
    def bind_paths = get_mounted_vols_opts(paths)
    "${params.runtime_opts} ${bind_paths}"
}

def get_mounted_vols_opts(paths) {
    def unique_paths = paths.unique(false)
    switch (workflow.containerEngine) {
        case 'docker': 
            return unique_paths.collect { "-v $it:$it" }
                               .join(' ')
        case 'singularity':
            return unique_paths.collect { "-B $it" }
                               .join(' ')
        default:
            log.error "Unsupported container engine: ${workflow.containerEngine}"
            ''
    }
}
