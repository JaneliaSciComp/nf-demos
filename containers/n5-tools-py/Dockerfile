# Create final image
FROM continuumio/miniconda3:4.8.2

RUN conda create -n myenv -c conda-forge python=3.7 tqdm numpy=1.19.4 scikit-image=0.17 \
        zarr=2.7 dask=2021.3.1 dask-image=0.5.0 -y \
    && conda run -n myenv pip install xarray-multiscale \
    && conda clean --tarballs \
    && mkdir -p /opt/conda/envs/myenv/etc/conda/activate.d \
    # It's necessary to set TMPDIR for running with Singularity, because /opt/conda will be read-only
    && echo "export TMPDIR=/tmp" > /opt/conda/envs/myenv/etc/conda/activate.d/env_vars.sh

# ps is needed by nextflow to collect task metrics
RUN apt-get install -y procps

COPY scripts /app

#ENTRYPOINT ["conda", "run", "--no-capture-output", "-n", "myenv", "python", "run.py"]

RUN echo "#!/bin/bash" >> /entrypoint.sh \
    && echo "source /opt/conda/etc/profile.d/conda.sh" >> /entrypoint.sh \
    && echo "SCRIPT_NAME=\$1; shift" >> /entrypoint.sh \
    && echo "conda activate myenv" >> /entrypoint.sh \
    && echo 'python /app/${SCRIPT_NAME}.py "$@"' >> /entrypoint.sh \
    && chmod +x /entrypoint.sh
ENTRYPOINT [ "/entrypoint.sh" ]
