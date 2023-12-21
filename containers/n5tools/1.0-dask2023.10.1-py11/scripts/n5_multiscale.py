#!/usr/bin/env python
'''
Add multiscale imagery to n5 volume
'''

import argparse
import math
import numpy as np
import dask.array as da
import zarr

from dask.diagnostics import ProgressBar
from xarray_multiscale import (multiscale, reducers)
from zarr.errors import PathNotFoundError

def add_metadata(n5_path, downsampling_factors=(2,2,2), axes=("x","y","z"), pixel_res=None, pixel_res_units="nm"):
    store = zarr.N5Store(n5_path)
    scales = []

    for idx in range(20):
        try:
            zarr.open(store, path=f'/s{idx}', mode='r')
        except PathNotFoundError:
            break
        factors = tuple([int(math.pow(f,idx)) for f in downsampling_factors])
        print(f"Setting downsampling factors for scale {idx} to {factors}")
        scales.append(factors)
        if idx>0:
            z = zarr.open(store, path=f'/s{idx}', mode='a')
            z.attrs["downsamplingFactors"] = factors

    # Add metadata at the root
    z = zarr.open(store, path='/', mode='a')
    z.attrs["scales"] = scales
    if axes:
        z.attrs["axes"] = axes
    if pixel_res:
        z.attrs["pixelResolution"] = {
            "dimensions": pixel_res,
            "unit": pixel_res_units
        }
    print("Added multiscale metadata to", n5_path)


def add_multiscale(n5_path, data_set, downsampling_factors=(2,2,2), \
        downsampling_method=reducers.windowed_mean,
        thumbnail_size_yx=None):
    '''
    Given an n5 with "s0", generate downsampled versions s1, s2, etc., up to the point where
    the smallest version is larger than thumbnail_size_yx (which defaults to the chunk size).
    '''
    print('Generating multiscale for', n5_path, data_set)
    store = zarr.N5Store(n5_path)

    # Find out what compression is used for s0, so we can use the same for the multiscale
    fullscale = f'{data_set}/s0' if data_set != '/' else '/s0'
    r = zarr.open(store=store, mode='r')
    compressor = r[fullscale].compressor

    volume = da.from_zarr(store, component=fullscale)
    chunk_size = volume.chunksize
    thumbnail_size_yx = thumbnail_size_yx or chunk_size
    multi = multiscale(volume, downsampling_method, downsampling_factors, chunks=chunk_size)
    
    thumbnail_sized = [np.less_equal(m.shape, thumbnail_size_yx).all() for m in multi]
    
    try:
        cutoff = thumbnail_sized.index(True)
        multi_to_save = multi[0:cutoff + 1]
    except ValueError:
        # All generated versions are larger than thumbnail_size_yx
        multi_to_save = multi

    for idx, m in enumerate(multi_to_save):
        if idx==0: continue
        print(f'Saving level {idx} with shape {m.shape}')
        component = f'{data_set}/s{idx}'

        m.data.to_zarr(store, 
                       component=component, 
                       overwrite=True, 
                       compressor=compressor)

        z = zarr.open(store, path=component, mode='a')
        z.attrs["downsamplingFactors"] = tuple([int(math.pow(f,idx)) for f in downsampling_factors])

    print("Added multiscale imagery to", n5_path)


def main():
    parser = argparse.ArgumentParser(description='Add multiscale levels to an existing n5')

    parser.add_argument('-i', '--input', dest='input_path', type=str, required=True, \
        help='Path to the directory containing the n5 volume')

    parser.add_argument('-d', '--data_set', dest='data_set', type=str, default="", \
        help='Path to data set (default empty, so /s0 is assumed to exist at the root)')

    parser.add_argument('-f', '--downsampling_factors', dest='downsampling_factors', type=str, default="2,2,2", \
        help='Downsampling factors for each dimension (default "2,2,2")')

    parser.add_argument('-p', '--pixel_res', dest='pixel_res', type=str, \
        help='Pixel resolution for each dimension "2.0,2.0,2.0" (default None) - required for Neuroglancer')

    parser.add_argument('-u', '--pixel_res_units', dest='pixel_res_units', type=str, default="nm", \
        help='Measurement unit for --pixel_res (default "nm") - required for Neuroglancer')

    parser.add_argument('--dask-scheduler', dest='dask_scheduler', type=str, default=None, \
        help='Run with distributed scheduler')

    parser.add_argument('--metadata-only', dest='metadata_only', action='store_true', \
        help='Only fix metadata on an existing multiscale pyramid')
    parser.set_defaults(metadata_only=False)

    args = parser.parse_args()

    if args.dask_scheduler:
        from dask.distributed import Client
        client = Client(address=args.dask_scheduler)
    else:
        client = None

    pbar = ProgressBar()
    pbar.register()

    downsampling_factors = [int(c) for c in args.downsampling_factors.split(',')]

    pixel_res = None
    if args.pixel_res:
        pixel_res = [float(c) for c in args.pixel_res.split(',')]

    if not args.metadata_only:
        add_multiscale(args.input_path, args.data_set, downsampling_factors=downsampling_factors)

    add_metadata(args.input_path, downsampling_factors=downsampling_factors, pixel_res=pixel_res, pixel_res_units=args.pixel_res_units)

    if client is not None:
        client.close()


if __name__ == "__main__":
    main()