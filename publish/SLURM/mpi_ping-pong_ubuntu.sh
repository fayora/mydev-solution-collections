#!/bin/bash
#SBATCH --job-name=mpi_ping-pong
#SBATCH --nodes=2

# !NOTE: it is a good idea to check what version of Intel MPI 2021 is available on the nodes before running this script
#        To check the version, run: module avail mpi/impi
IMPI_VERSION="2021.6.0"

echo ""
echo "********************************************************************************"
echo "****************** Intel MPI 2021 -- Ping-pong test over RDMA ******************"
echo "********************************************************************************"
echo ""
export INTELMPI_ROOT=/opt/intel/oneapi/mpi/latest
export I_MPI_FABRICS=shm:ofi
export I_MPI_OFI_PROVIDER=mlx
# !!IMPORTANT: FI_PROVIDER=verbs is less performant than mlx! 
export FI_PROVIDER=mlx
export I_MPI_ROOT=/opt/intel/oneapi/mpi/latest
# The Intel MPI module needs to be loaded, as explained here: https://techcommunity.microsoft.com/t5/azure-compute-blog/azure-hpc-vm-images/ba-p/977094
module load mpi/impi_$IMPI_VERSION
source /opt/intel/oneapi/mpi/$IMPI_VERSION/etc/conda/activate.d/mpivars.activate.sh
mpirun IMB-MPI1 pingpong

echo ""
echo "********************************************************************************"
echo "****************** Intel MPI 2021 -- Ping-pong test over TCP *******************"
echo "********************************************************************************"
echo ""
export FI_PROVIDER=tcp
export FI_TCP_IFACE=eth0
mpirun IMB-MPI1 pingpong

######################################################
# Expected results for 2 nodes
######################################################
# For: HC44rs with 100 Gb/sec EDR InfiniBand
#-----------------------------------------------------
    #    #bytes #repetitions      t[usec]   Mbytes/sec
    #         0         1000         1.57         0.00
    #         1         1000         1.58         0.63
    #         2         1000         1.56         1.29
    #         4         1000         1.56         2.56
    #         8         1000         1.56         5.12
    #        16         1000         1.56        10.24
    #        32         1000         1.63        19.64
    #        64         1000         1.92        33.26
    #       128         1000         2.02        63.49
    #       256         1000         2.56       100.12
    #       512         1000         2.61       196.49
    #      1024         1000         2.80       366.00
    #      2048         1000         3.27       627.15
    #      4096         1000         3.92      1045.71
    #      8192         1000         4.99      1641.26
    #     16384         1000         6.76      2422.31
    #     32768         1000        11.14      2940.29
    #     65536          640        13.79      4754.11
    #    131072          320        19.17      6836.96
    #    262144          160        30.38      8627.57
    #    524288           80        53.29      9838.02
    #   1048576           40        98.42     10653.60
    #   2097152           20       188.53     11123.70
    #   4194304           10       369.51     11351.09
#
#-----------------------------------------------------
# For: HB120rs_v2 with 200 Gb/sec HDR InfiniBand
#-----------------------------------------------------
    #    #bytes #repetitions      t[usec]   Mbytes/sec
    #         0         1000         1.51         0.00
    #         1         1000         1.50         0.67
    #         2         1000         1.50         1.33
    #         4         1000         1.50         2.67
    #         8         1000         1.50         5.34
    #        16         1000         1.50        10.64
    #        32         1000         1.65        19.34
    #        64         1000         1.77        36.22
    #       128         1000         1.81        70.60
    #       256         1000         2.38       107.73
    #       512         1000         2.52       203.28
    #      1024         1000         2.61       391.87
    #      2048         1000         2.85       718.42
    #      4096         1000         3.38      1213.16
    #      8192         1000         3.86      2119.60
    #     16384         1000         5.24      3127.68
    #     32768         1000         8.32      3938.32
    #     65536          640        10.05      6517.84
    #    131072          320        12.91     10151.47
    #    262144          160        19.20     13652.63
    #    524288           80        31.21     16801.13
    #   1048576           40        54.81     19131.40
    #   2097152           20       100.65     20836.12
    #   4194304           10       189.61     22121.02