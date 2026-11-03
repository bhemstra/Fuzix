#!/bin/sh
#
#	Make the disk file the page loads from the Model II hard disk image:
#	gzip compressed and base64 encoded (artifact hosts only serve text).
#
#	mkdisk.sh [image]	default ../../Images/trs80m2/hard2-0.hdv
#
set -e
cd "$(dirname "$0")"
IMG=${1:-../../Images/trs80m2/hard2-0.hdv}
gzip -9 -c "$IMG" | base64 -w0 > hard2-0.hdv.gz.b64.txt
ls -l hard2-0.hdv.gz.b64.txt
