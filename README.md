# sysbench-suite

cloud-init scripts to automatically create benchmarks

- https://ittutorial.org/how-to-benchmark-performance-of-mysql-using-sysbench/

Make sure that the file size in the `run.sh` is larger than
the memory available on the system.  Otherwise, the File I/O
benchmarks will be testing the cache.

# TODO

- normalization script
