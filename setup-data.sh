#!/bin/sh
#
# Set-up data disks
#
mkdir -p /data

data_dev=""
for syspath in /sys/class/block/*
do
  [ ! -d $syspath/device ] && continue
  devname=$(basename "$syspath")
  if [ -n "$(blkid /dev/$devname)" ] ; then
    # Not an empty device
    continue
  fi
  #~ # Partitions exist!
  #~ [ -n "$(ls -1 /dev/$devname[0-9]* 2>/dev/null)" ] && continue
  data_dev="$devname"
  break
done
if [ -z "$data_dev" ] ; then
  echo "data disk not found" 1>&2
  exit 1
fi

echo $data_dev

# Create file system
mkfs.xfs /dev/sda
mount /dev/sda /data

