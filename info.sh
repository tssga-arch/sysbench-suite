#!/bin/sh
#
# Create info files
#
if [ $# -ne 1 ] ; then
  echo "Usage: $0 {target-dir}"
  exit 1
fi

output="$1"
if [ ! -d "$output" ] ; then
  echo "$output: directory does not exist!"
  exit 2
fi

catpart() {
  cat /proc/partitions
}

root() {
  if [ $(id -u) -ne 0 ] ; then
    sudo "$@"
  else
    "$@"
  fi
}

scsi_sd() {
  root dmesg | sed -e 's/\[\s*/[/' | awk '$2 == "sd" || $2 == "scsi"'
}


for cmd in lspci dmidecode lscpu lshw catpart scsi_sd uptime
do
  type $cmd && $cmd > "$output/$cmd.txt"
done

