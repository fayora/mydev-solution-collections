#!/bin/bash
#SBATCH --job-name=mpi_ping-pong
#SBATCH --nodes=2

export INTELMPI_ROOT=/opt/intel/oneapi/mpi/latest
export I_MPI_FABRICS=shm:dapl
export I_MPI_DAPL_PROVIDER=ofa-v2-ib0
export I_MPI_ROOT=/opt/intel/oneapi/mpi/latest
#source /opt/intel/impi/2017.2.174/bin64/mpivars.sh  # <<< Cannot find this in Ubuntu!! (it is from CentOS)

# For Ubuntu, we load Intel MPI as explained here: https://techcommunity.microsoft.com/t5/azure-compute-blog/azure-hpc-vm-images/ba-p/977094
module load mpi/impi_2021.6.0

#cat "$TMPDIR/machines"
#cat "$PE_HOSTFILE"

#for i in `seq 1 $PPN`;
#do
#  uniq $TMPDIR/machines >> $TMPDIR/u_machines
#done

echo "Run a ping-pong test over RDMA:"
#time mpirun -machinefile "$TMPDIR/u_machines" IMB-MPI1 pingpong
time mpirun IMB-MPI1 pingpong

echo "Run a ping-pong test over TCP:"
export I_MPI_FABRICS=tcp
#time mpirun -machinefile "$TMPDIR/u_machines" IMB-MPI1 pingpong
time mpirun IMB-MPI1 pingpong