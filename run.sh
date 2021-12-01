#!/bin/sh
#

if [ $# -ne 1 ] ; then
  echo "Usage; $0 {resdir}"
  exit 1
fi

resdir="$1"

if [ -e "$resdir" ] ; then
  echo "$resdir: already exists!"
  exit 1
fi
mkdir -p "$resdir"

test_secs=300
tests="cpu mem fio oltp"
fio_args='--file-num=128 --file-total-size=8G'

fname() {
  local c=0
  while [ -f "$1-$c.txt" ]
  do
    c=$(expr $c + 1)
  done
  echo "$1-$c.txt" $c
}

root() {
  if [ $(id -u) -ne 0 ] ; then
    sudo "$@"
  else
    "$@"
  fi
}


sb_cpu() {
  local nt="$1" resdir="$2"

  set - $(fname $resdir/cpu.$nt)
  local fname="$1"
  local cnt=$2

  sysbench --time=$test_secs --threads=$nt cpu run > "$fname"

  #~ local score=$(grep 'events per second' "$fname" | cut -d: -f2 | tr -d ' ')
  #~ echo "cpu,$nt,$score,events/sec" >> "$resdir/score.csv"
}

sb_mem() {
  local nt="$1" resdir="$2"

  for op in read write
  do
    for mode in seq rnd
    do
      set - $(fname $resdir/mem-$mode-$op.$nt)
      local fname="$1"
      local cnt=$2

      sysbench --time=$test_secs --threads=$nt --memory-oper=$op --memory-access-mode=$mode memory run > "$fname"

      #~ local score=$(grep 'MiB transferred' "$fname" | cut -d\( -f2 | cut -d\) -f1|tr ' ' ',')
      #~ echo "mem-$mode-$op,$nt,$score" >> "$resdir/score.csv"
    done
  done
}

sb_fio() {
  local nt="$1" resdir="$2"


  for mode in seqwr seqrewr seqrd rndrd rndwr rndrw
  do
    set - $(fname $resdir/fio-$mode.$nt)
    local fname="$1"
    local cnt=$2

    sysbench $fio_args fileio prepare
    sysbench $fio_args --time=$test_secs --threads=$nt --file-test-mode=$mode fileio run > "$fname"

    #~ for ln in $(grep '/s' "$fname" | grep -E '(read|writ)' | grep -v '0.00'| tr -d ' ' | tr ':/' ,,)
    #~ do
      #~ set - $(echo "$ln" | tr , ' ')
      #~ if [ $# -eq 3 ] ; then
        #~ set - fio-$mode.$nt-$1 $3 iop/sec
      #~ elif [ $# -eq 4 ] ; then
        #~ set - fio-$mode.$nt-$1 $4 MiB/sec
      #~ else
        #~ continue
      #~ fi
      #~ echo "$*" | tr ' ' ',' >> "$resdir/score.csv"
    #~ done
  done
}

sb_fio_cleanup() {
  sysbench $fio_args fileio cleanup
}

sb_oltp() {
  local nt="$1" resdir="$2"

  for mode in read_write update_index update_non_index read_only write_only
  do
    set - $(fname $resdir/oltp-$mode.$nt)
    local fname="$1"
    local cnt=$2

    root mysql <<-'EOF'
		create database sbtest;
		create user sbtest_user identified by 'password';
		grant all on sbtest.* to `sbtest_user`@`%`;
		show grants for sbtest_user;
		EOF

    sysbench \
		--db-driver=mysql \
		--mysql-user=sbtest_user \
		--mysql_password=password \
		--mysql-db=sbtest \
		--mysql-host=localhost \
		--mysql-port=3306 \
		--tables=16 \
		--table-size=10000 \
		/usr/share/sysbench/oltp_${mode}.lua prepare
    sysbench \
		--db-driver=mysql \
		--mysql-user=sbtest_user \
		--mysql_password=password \
		--mysql-db=sbtest \
		--mysql-host=localhost \
		--mysql-port=3306 \
		--tables=16 \
		--table-size=10000 \
   		--time=$test_secs --threads=$nt \
		/usr/share/sysbench/oltp_${mode}.lua run > "$fname"

    root mysql <<-'EOF'
		drop database sbtest;
		drop user sbtest_user;
		EOF
  done
}

#~ runs="1"
#~ [ $(nproc) -gt 1 ] && runs="$runs $(nproc)"
runs="$(nproc)"

for cc in $tests
do
  type sb_${cc}_prepare 2>/dev/null && sb_${cc}_prepare
  for q in $runs
  do
    echo "RUN: $cc $q"
    sb_${cc} "$q" "$resdir"
  done
  type sb_${cc}_cleanup 2>/dev/null && sb_${cc}_cleanup
done
