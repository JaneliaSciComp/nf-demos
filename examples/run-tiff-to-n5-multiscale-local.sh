DATA_DIR=${DATA_DIR:-local/data}

n5-tools-dask/tiff-to-n5-multiscale.nf \
    -c nextflow-Darwin-arm64.config \
    --inputPath ${DATA_DIR}/leiz_s2L13sv/c1 \
    --outputPath ${DATA_DIR}/leiz_s2L13sv/c1-res.n5 \
    --blockSize 128,128,128 \
    --cpus 5 \
    --mem_gb 18
