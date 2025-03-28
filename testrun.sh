#!/usr/bin/env bash

docker run \
    --mount type=bind,src=$(pwd -P)/INPUTS,dst=/INPUTS \
    --mount type=bind,src=$(pwd -P)/OUTPUTS,dst=/OUTPUTS \
    eprime-stable3:test \
    --eprime_txt /INPUTS/eprime.txt \
    --fmri_dcm /INPUTS/fmrislice.dcm \
    --timeoverride 1
