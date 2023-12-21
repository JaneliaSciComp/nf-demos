# Create final image
FROM  quay.io/bioimagetools/dask:2023.10.1-py11-ol9

ARG TARGETPLATFORM

# Use the base environment from the baseImage
COPY conda-env.yml /tmp/

RUN mamba env update -n base -f /tmp/conda-env.yml

WORKDIR /app

COPY scripts /app/
