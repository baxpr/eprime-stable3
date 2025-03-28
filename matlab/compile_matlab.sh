#!/bin/bash

export MATLABROOT=~/MATLAB/R2023a
export PATH=${MATLABROOT}/bin:${PATH}

# Compile. Use -a to include an entire directory and all its contents,
# recursively. We use this for our own code. Use -N to leave out toolboxes to
# reduce the size of the binary. Individual toolboxes can be added back in with
# -p if needed. Use -C to avoid embedding the archive in the binary - there 
# won't be disk space available in the container to extract it at run time, so
# we extract it ahead of time during the singularity build.
#
# Relative paths are specified here, assuming we're running this script from
# the matlab/build directory.
#
# More info: https://www.mathworks.com/help/compiler/mcc.html
mcc -m -C -v src/matlab_entrypoint.m \
    -a src \
    -d bin

# We grant lenient execute permissions to the matlab executable and runscript so
# we don't have hiccups later.
chmod go+rx bin/matlab_entrypoint
chmod go+rx bin/run_matlab_entrypoint.sh

