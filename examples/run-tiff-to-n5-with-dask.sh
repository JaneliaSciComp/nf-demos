DATA_DIR=${DATA_DIR:-local/data}

n5-tools-dask/tiff-to-n5.nf \
    -c nextflow-Darwin-arm64.config \
    --inputPath ${DATA_DIR}/leiz_s2L13sv/c1 \
    --outputPath ${DATA_DIR}/leiz_s2L13sv/c1-res.n5 \
    --blockSize 128,128,128 \
    --with_dask_cluster \
    --workers 6 \
    --required_workers 4 \
    --worker_mem_gb_per_core 2
