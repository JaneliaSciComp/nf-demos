#!/usr/bin/env python

import argparse
import numpy as np 
import zarr 
import dask.array as da
from xarray_multiscale import multiscale


def add_multiscale(input_path, data_set, downsampling_factors=(2,2,2), \
        downsampling_method=np.mean, thumbnail_size_yx=None):
    '''
    Given an n5 with "s0", generate downsampled versions s1, s2, etc., up to the point where
    the smallest version is larger than thumbnail_size_yx (which defaults to the chunk size).
    '''
    print('Generating multiscale for', input_path)
    store = zarr.N5Store(input_path)
    volume = da.from_zarr(store, component=f'{data_set}/s0')
    print(volume)
    chunk_size = volume.chunksize
    if not thumbnail_size_yx: thumbnail_size_yx = chunk_size
    multi = multiscale(volume, downsampling_method, downsampling_factors, chunks=chunk_size)
    thumbnail_sized = [np.less_equal(m.shape, thumbnail_size_yx).all() for m in multi]
    cutoff = thumbnail_sized.index(True)
    multi_to_save = multi[0:cutoff + 1]
    
    for idx, m in enumerate(multi_to_save):
        if idx==0: continue
        print(f'Saving level {idx}')
        m.data.to_zarr(store, component=f'{data_set}/s{idx}', overwrite=True)
        z = zarr.open(store, path=f'{data_set}/s{idx}', mode='a')
        z.attrs["downsamplingFactors"] = np.power(downsampling_factors, idx)
        
    print("Added multiscale to", input_path)


def main():
    parser = argparse.ArgumentParser(description='Add multiscale levels to an existing n5')

    parser.add_argument('-i', '--input', dest='input_path', type=str, required=True, \
        help='Path to the directory containing the n5 volume')

    parser.add_argument('-d', '--data_set', dest='data_set', type=str, default="", \
        help='Path to data set (default empty, so /s0 is assumed to exist at the root)')

    parser.add_argument('-f', '--downsampling_factors', dest='downsampling_factors', type=str, default="2,2,2", \
        help='Downsampling factors for each dimension (default "2,2,2")')

    parser.add_argument('--distributed', dest='distributed', action='store_true', \
        help='Run with distributed scheduler (default)')
    parser.set_defaults(distributed=False)

    parser.add_argument('--workers', dest='workers', type=int, default=20, \
        help='If --distributed is set, this specifies the number of workers (default 20)')

    parser.add_argument('--dashboard', dest='dashboard', action='store_true', \
        help='Run a web-based dashboard on port 8787')
    parser.set_defaults(dashboard=False)

    args = parser.parse_args()

    if args.distributed:
        dashboard_address = None
        if args.dashboard: 
            dashboard_address = ":8787"
            print(f"Starting dashboard on {dashboard_address}")

        from dask.distributed import Client
        client = Client(processes=True, n_workers=args.workers, \
            threads_per_worker=1, dashboard_address=dashboard_address)
        client.cluster
        
    else:
        from dask.diagnostics import ProgressBar
        pbar = ProgressBar()
        pbar.register()

    add_multiscale(args.input_path, args.data_set, \
        downsampling_factors=[int(c) for c in args.downsampling_factors.split(',')])


if __name__ == "__main__":
    main()