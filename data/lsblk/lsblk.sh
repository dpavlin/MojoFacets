#!/bin/sh -x

cols=`lsblk -h | grep '^ *[A-Z][A-Z][A-Z]*' | sed 's/^ *//' | cut -d" " -f1 | grep -v DISC-ZERO | xargs echo | sed 's/ /,/g'`
echo $cols
lsblk --pairs --output $cols > `hostname`.pairs
