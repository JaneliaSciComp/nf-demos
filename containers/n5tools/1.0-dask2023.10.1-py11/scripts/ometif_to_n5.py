#!/usr/bin/env python

import argparse
import dask
import dask.array as da
import dask.bag as db
import numpy as np
import numcodecs as codecs
import ome_types
import time
import yaml
import zarr

from dask.distributed import (Client, LocalCluster)
from flatten_json import flatten
from tifffile import TiffFile


def _ometif_to_n5_volume(input_path, output_path, 
                         data_set, compressor,
                         chunk_size=(128,128,128),
                         zscale=1.0):
    """
    Convert OME-TIFF into an n5 volume with given chunk size.
    """
    with TiffFile(input_path) as tif:
        if not tif.is_ome:
            print(f'{input_path} is not an OME-TIFF. ',
                  'This method only supports OME TIFF', flush = True)
            return
        tif_series = tif.series[0]
        data_shape = tif_series.shape
        data_type = tif_series.dtype
        dims = [d for d in tif_series.axes.lower()
                                .replace('i', 'z')
                                .replace('s', 'c')]
        indexed_dims = {dim:i for i,dim in enumerate(dims)}
        ome = ome_types.from_xml(tif.ome_metadata)
        scale = { d:getattr(ome.images[0].pixels, f'physical_size_{d}', None)
                  for d in dims}
        if scale['z'] is None:
            scale['z'] = zscale

        n_channels = data_shape[indexed_dims['c']]
        volume_shape = (data_shape[indexed_dims['c']],
                        data_shape[indexed_dims['z']],
                        data_shape[indexed_dims['y']],
                        data_shape[indexed_dims['x']])

        print(f'Input tiff info - ',
              f'ome: {ome.images[0]},',
              f'dims: {dims} ', 
              f'scale: {scale} ',
              f'shape: {data_shape}',
              f'channels: {n_channels}',
              f'volume_shape: {volume_shape}',
              flush=True)

    # include channel in computing the blocks and for channels use a chunk of 1
    czyx_chunk_size=(n_channels,) + tuple(chunk_size)
    print(f'Actual chunk size: {czyx_chunk_size}', flush=True)
    czyx_block_size = np.array(czyx_chunk_size, dtype=int)
    block_size = czyx_to_actual_order(czyx_block_size, np.empty_like(czyx_block_size),
                                      indexed_dims['c'], indexed_dims['z'],
                                      indexed_dims['y'], indexed_dims['x'])
    czyx_nblocks = np.ceil(np.array(volume_shape) / czyx_chunk_size).astype(int)
    nblocks = tuple(czyx_to_actual_order(czyx_nblocks, [0, 0, 0, 0],
                                        indexed_dims['c'], indexed_dims['z'],
                                        indexed_dims['y'], indexed_dims['x']))
    print(f'{volume_shape} -> {czyx_nblocks} ({nblocks}) blocks', flush=True)

    output_container = _create_root_output(output_path,
                                           pixelResolutions=[scale['x'],
                                                             scale['y'],
                                                             scale['z']])
    for c in range(n_channels):
        output_container.require_dataset(f'c{c}/{data_set}',
                                         shape=volume_shape[1:],
                                         chunks=chunk_size,
                                         dtype=data_type,
                                         compressor=compressor)

    print(f'Saving {nblocks} blocks to {output_path}', flush=True)

    persisted_blocks = []
    for block_index in np.ndindex(*nblocks):
        block_start = block_size * block_index
        block_stop = np.minimum(data_shape, block_start + block_size)
        block_slices = tuple([slice(start, stop)
                              for start, stop in zip(block_start, block_stop)])
        block_shape = tuple([s.stop - s.start for s in block_slices])
        data_block = dask.delayed(_get_block_data)(
            input_path,
            block_index,
            block_slices,
        )
        block = da.from_delayed(data_block, shape=block_shape, dtype=data_type)
        for c in range(n_channels):
            dflag = dask.delayed(_save_block)(
                block,
                block_index,
                block_slices,
                indexed_dims=indexed_dims,
                output_container=output_container,
                data_set=data_set,
                channel=c,
            )
            resolved_dflag = da.from_delayed(dflag, shape=(), dtype=np.uint16)
            persisted_blocks.append(resolved_dflag)

    return da.from_array(persisted_blocks, chunks=(1,))


def czyx_to_actual_order(czyx, data, c_index, z_index, y_index, x_index):
    data[c_index] = czyx[0]
    data[z_index] = czyx[1]
    data[y_index] = czyx[2]
    data[x_index] = czyx[3]
    return data


def _create_root_output(data_path, pixelResolutions=None):
    try:
        n5_root = zarr.open_group(store=zarr.N5Store(data_path), mode='a')
        if (pixelResolutions is not None):
            pixelResolution = {
                'unit': 'um',
                'dimensions': pixelResolutions,
            }
        n5_root.attrs.update(pixelResolution=pixelResolution)
        return n5_root
    except Exception as e:
        print(f'Error creating a N5 root: {data_path}', e, flush=True)
        raise e


def _get_block_data(image_path, block_index, block_coords):
    print(f'{time.ctime(time.time())} '
        f'Get block: {block_index}, from: {block_coords}',
        flush=True)
    with TiffFile(image_path) as tif:
        data_store = tif.series[0].aszarr()
        image_data = zarr.open(data_store, 'r')
        block_data = image_data[block_coords]
        return block_data


def _save_block(block, block_index, block_coords,
                indexed_dims=None, output_container=None,
                data_set='s0', channel=0):

    subpath = f'c{channel}/{data_set}'
    ch_selection = tuple([slice(0,s) if i != indexed_dims['c'] 
                                     else channel
                          for i,s in enumerate(block.shape)])
    output_block_index = tuple([block_index[indexed_dims['z']],
                                block_index[indexed_dims['y']],
                                block_index[indexed_dims['x']]])
    output_coords = tuple([block_coords[indexed_dims['z']],
                           block_coords[indexed_dims['y']],
                           block_coords[indexed_dims['x']]])
    output_block_data = block[ch_selection]

    print(f'{time.ctime(time.time())} '
          f'Write: {subpath}:{output_block_index}(ch selection:{ch_selection}):',
          f'{block_coords}({block.shape}) -> {output_coords}({output_block_data.shape})',
          flush=True)
    output_container[subpath][output_coords] = output_block_data


def main():
    parser = argparse.ArgumentParser(description='Convert a TIFF series to a chunked n5 volume')

    parser.add_argument('-i', '--input', dest='input_path', type=str,
        required=True,
        help='Path to the directory containing the TIFF series')

    parser.add_argument('-o', '--output', dest='output_path', type=str,
        required=True,
        help='Path to the n5 directory')

    parser.add_argument('-d', '--data_set', dest='data_set', type=str,
        default='/s0',
        help='Path to output data set (default is /s0)')

    parser.add_argument('-c', '--chunk_size', dest='chunk_size', type=str,
        default='128,128,128',
        help='Comma-delimited list describing the chunk size (x,y,z)')

    parser.add_argument('--z-scale', dest='z_scale', type=float,
        default=0.42,
        help='Z scale')

    parser.add_argument('--compression', dest='compression', type=str,
        default='bz2',
        help='Set the compression. Valid values any codec id supported by numcodecs including: raw, lz4, gzip, bz2, blosc. Default is bz2.')

    parser.add_argument('--dask-config', '--dask_config',
                        dest='dask_config',
                        type=str, default=None,
                        help='Dask configuration yaml file')
    parser.add_argument('--dask-scheduler', dest='dask_scheduler', type=str,
        default=None,
        help='Run with distributed scheduler')

    args = parser.parse_args()

    if args.compression=='raw':
        compressor = None
    else:
        compressor = codecs.get_codec(dict(id=args.compression))

    if args.dask_config:
        import dask.config
        print(f'Use dask config: {args.dask_config}', flush=True)
        with open(args.dask_config) as f:
            dask_config = flatten(yaml.safe_load(f))
            dask.config.set(dask_config)

    if args.dask_scheduler:
        client = Client(address=args.dask_scheduler)
    else:
        client = Client(LocalCluster())

    # the chunk size input arg is given in x,y,z order
    # so after we extract it from the arg we have to revert it
    # and pass it to the function as z,y,x
    zyx_chunk_size = [int(c) for c in args.chunk_size.split(',')][::-1]
    persisted_blocks = _ometif_to_n5_volume(args.input_path,
                                            args.output_path,
                                            args.data_set,
                                            compressor,
                                            chunk_size=zyx_chunk_size,
                                            zscale=args.z_scale)

    print('Persisted blocks computation', persisted_blocks, flush=True)
    r = client.compute(persisted_blocks).result()
    print('Persisted blocks result', r, flush=True)


if __name__ == "__main__":
    main()
