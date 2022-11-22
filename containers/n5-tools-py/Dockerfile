# Create final image
FROM janeliascicomp/dask:2022.11.1

# Use the base environment from the baseImage
RUN mamba install -n base -c conda-forge \
    python=3.10.8 \
    tqdm \
    scikit-image=0.18 \
    zarr=2.7 dask-image=2022.9.0 \
    -y \
    && mamba run -n base pip install xarray-multiscale fibsem-tools \
    && mamba clean --tarballs -y

COPY scripts /app

RUN echo "#!/bin/bash" >> /entrypoint.sh \
    && echo "SCRIPT_NAME=\$1; shift" >> /entrypoint.sh \
    && echo 'python /app/${SCRIPT_NAME}.py "$@"' >> /entrypoint.sh \
    && chmod +x /entrypoint.sh
