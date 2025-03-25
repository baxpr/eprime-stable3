#!/usr/bin/env bash
#
# Copy tapas v5.1.2 source code here so we have a snapshot to use for compiling the matlab
# executable. We only need the HGF subdir - others are not extracted as some have lots of syntax
# errors that lead to compilation failures if they're in the path

wget https://github.com/translationalneuromodeling/tapas/archive/refs/tags/v5.1.2.tar.gz

tar -zxf v5.1.2.tar.gz \
    tapas-5.1.2/CHANGELOG.md \
    tapas-5.1.2/CONTRIBUTING.md \
    tapas-5.1.2/Contributor-License-Agreement.md \
    tapas-5.1.2/HGF \
    tapas-5.1.2/LICENSE \
    tapas-5.1.2/README.md

rm v5.1.2.tar.gz

