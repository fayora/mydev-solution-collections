#!/bin/bash
#SBATCH --job-name=mpi_ping-pong
#SBATCH --nodes=2


# Intel 2018
# !!IMPORTANT: CentOS 7.9 users OFA not DAPL.
# echo ""
# echo "********************************************************************************"
# echo "****************** Intel MPI 2018 -- Ping-pong test over RDMA ******************"
# echo "********************************************************************************"
# echo ""
# Intel 2018
# !NOTE: CentOS 7.9 users shm:ofa not shm:dapl
# export INTELMPI_ROOT=/opt/intel/impi/2018.4.274
# export I_MPI_FABRICS=shm:ofa
# export I_MPI_ROOT=/opt/intel/compilers_and_libraries/linux/mpi
# source /opt/intel/impi/2018.4.274/bin64/mpivars.sh
#
# echo "Ping-pong test over RDMA:"
# mpirun -machinefile "$TMPDIR/u_machines" IMB-MPI1 pingpong

# Intel 2021
echo ""
echo "********************************************************************************"
echo "****************** Intel MPI 2021 -- Ping-pong test over RDMA ******************"
echo "********************************************************************************"
echo ""
export INTELMPI_ROOT=/opt/intel/oneapi/mpi/2021.2.0
export I_MPI_FABRICS=shm:ofi
export I_MPI_OFI_PROVIDER=mlx
# !!IMPORTANT: FI_PROVIDER=verbs is less performant than mlx! 
export FI_PROVIDER=mlx I_MPI_OFI_EXPERIMENTAL=1
export I_MPI_ROOT=/opt/intel/oneapi/mpi/2021.2.0
module load mpi/impi_2021.2.0
source /opt/intel/oneapi/mpi/2021.2.0/etc/conda/activate.d/mpivars.activate.sh

echo "Ping-pong test over RDMA:"
/opt/intel/oneapi/mpi/2021.2.0/bin/mpirun IMB-MPI1 pingpong


### NOT USED because /tmp/machines is empty
# cat "$TMPDIR/machines"
# # cat "$PE_HOSTFILE"

# # for i in `seq 1 $PPN`;
# # do
# #   uniq $TMPDIR/machines >> $TMPDIR/u_machines
# # done

# echo "Run a ping-pong test over RDMA:"
# time mpirun -machinefile "$TMPDIR/u_machines" IMB-MPI1 pingpong
