#!/bin/bash
INPUT_DIR=$PWD
OUTPUT_DIR=$PWD
bsub -J "tif_to_n5" -P multifish -n 3 \
        -o $OUTPUT_DIR/tif2n5.log \
        $PWD/tif_to_n5.sh $INPUT_DIR $OUTPUT_DIR/export.n5
bsub -w "done("tif_to_n5")" -J "unet" -P multifish -n 4 \
        -gpu "num=1" -q gpu_rtx -o $OUTPUT_DIR/unet.log \
        $PWD/apply_unet.sh $OUTPUT_DIR/export.n5 $OUTPUT_DIR/predict.n5


