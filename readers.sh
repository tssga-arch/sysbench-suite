#!/bin/sh
#
# Read the different files
#
if [ $# -ne 2 ] ; then
  echo "Usage: $0 {data-dir} {output-file"
  exit 1
fi

data="$1"
if [ ! -d "$data" ] ; then
  echo "$data: directory does not exist!"
  exit 2
fi


read_cpu() {
  awk '$1 == "events" && $2 == "per" && $3 == "second:" { print "cpu,std" ",events/sec," $4 }' "$2"
}

read_mem() {
  local metric=$(basename "$2" | cut -d. -f1 | cut -d- -f2-)
  awk '$2 == "MiB" && $3 == "transferred" { print "mem,'$metric'" "," $5 "," $4  }' "$2" | tr -d '()'
}

read_fio() {
  local metric=$(basename "$2" | cut -d. -f1 | cut -d- -f2-)
  awk '
    $1 == "reads/s:" && $2 != "0.00" { print "fio,'$metric'-rd" ",iops/sec," $2 }
    $1 == "writes/s:" && $2 != "0.00" { print "fio,'$metric'-wr" ",iops/sec," $2 }
    $1 == "read," && $2 == "MiB/s:" && $3 != "0.00" { print "fio,'$metric'-rd" ",MiB/sec," $3 }
    $1 == "written," && $2 == "MiB/s:" && $3 != "0.00" { print "fio,'$metric'-wr" ",MiB/sec," $3 }
  ' "$2"
}

read_oltp() {
  local metric=$(basename "$2" | cut -d. -f1 | cut -d- -f2-)
  awk '
    $1 == "transactions:" { print "oltp,'$metric'" ",transactions/sec," $3 }
  ' "$2" | tr -d '()'
}



# read_cpu 4 cpu.4-0.txt
# read_mem 4 mem-rnd-read.4-0.txt
# read_fio 4 fio-rndrw.4-0.txt
# read_fio 4 fio-rndrd.4-0.txt
# read_oltp 4 oltp-read_write.4-0.txt

# exit

find "$data" -name '*.txt' | (while read fname
do
  tstclass=$(basename $fname | sed -e 's/^\([a-z]*\).*$/\1/')
  nthreads=$(basename $fname | cut -d. -f2- | cut -d- -f1)
  # echo class=$tstclass threads=$nthreads $fname
  if type read_${tstclass} >/dev/null 2>&1 ; then
    echo threads,$nthreads
    read_${tstclass} $nthreads "$fname"
  fi
done) | awk '
  BEGIN { FS=","; OFS=","}
  $1 == "threads" {
    threads = $2
  }
  $1 != "threads" {
  	print
  	k = $1 "," $3
  	suite[k] = $1
  	units[k] = $3
  	sum[k] = sum[k] + $4
  	count[k] += 1
  }
  END {
	print "_threads_","","",threads
  	for (i in suite) {
  	  print suite[i], "z_AVG_", units[i], sum[i]/count[i]
  	}
  }
' | sort | tee "$2" | awk '
    BEGIN {
      FS=","; OFS=","
      i=0
    }
    {
      hdr[i] = $1 " " $2 " " $3
      row[i++] = $4
    }
    END {
      cols = i
      for (i=0; i < cols; i++) {
	printf ",%s",hdr[i]
      }
      printf "\n"
      for (i=0; i < cols; i++) {
	printf ",%s",row[i]
      }
      printf "\n"
    }

'
