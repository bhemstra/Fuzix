#!/bin/sh
#
#	Make a disk file the page can load from a Model II hard disk image.
#
#	mkdisk.sh [image [name]]	writes <name>.hdv.gz (for a web site)
#	mkdisk.sh -b [image [name]]	writes <name>.hdv.gz.b64.txt (for hosts
#					that only serve text, like artifacts)
#
#	Default image ../../Images/trs80m2/hard2-0.hdv, default name the
#	image name. Add the file to disks.json to make it selectable.
#
set -e
B64=
if [ "$1" = "-b" ]; then B64=1; shift; fi
IMG=${1:-$(dirname "$0")/../../Images/trs80m2/hard2-0.hdv}
NAME=${2:-$(basename "$IMG" .hdv)}
OUT=$(dirname "$0")/$NAME.hdv.gz
if [ -n "$B64" ]; then
	gzip -9 -c "$IMG" | base64 -w0 > "$OUT.b64.txt"
	ls -l "$OUT.b64.txt"
else
	gzip -9 -c "$IMG" > "$OUT"
	ls -l "$OUT"
fi
