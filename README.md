# Nextflow demos

This repository demonstrates a few simple Nextflow pipelines for large data image processing, mainly for working with the n5/zarr image formats. 

## Quick Start

The only software requirements for running this pipeline are [Nextflow](https://www.nextflow.io) (version 20.10.0 or greater) and [Singularity](https://sylabs.io) (version 3.5 or greater). If you are running in an HPC cluster, ask your system administrator to install Singularity on all the cluster nodes.

To [install Nextflow](https://www.nextflow.io/docs/latest/getstarted.html):

    curl -s https://get.nextflow.io | bash 

Alternatively, you can install it as a conda package:

    conda create --name nf-demos -c bioconda nextflow

To [install Singularity](https://sylabs.io/guides/3.7/admin-guide/installation.html) on CentOS Linux:

    sudo yum install singularity

Clone the multifish repository with the following command:

    git clone https://github.com/JaneliaSciComp/nf-demos.git

Before running the pipeline for the first time, run setup to pull in external dependencies:

    ./setup.sh
    
You can now launch a pipeline, e.g.:

    ./n5-tools-dask/tiff-to-n5.nf.nf [arguments]
