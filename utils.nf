
def getOptions(paths) { 
    def uniquePaths = paths.unique(false)
    switch (workflow.containerEngine) {
        case 'docker': 
            def bindPaths = uniquePaths.collect { "-v $it:$it" } join(' ')
            return "${params.runtime_opts} ${bindPaths}"
        case 'singularity':
            def bindPaths = uniquePaths.collect { "-B $it" } join(' ')
            return "${params.runtime_opts} ${bindPaths}"
        default:
            throw new IllegalStateException("Container engine is not supported: ${workflow.containerEngine}")
    }
}

