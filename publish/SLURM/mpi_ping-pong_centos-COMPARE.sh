#!/bin/bash
#SBATCH --job-name=mpi_ping-pong
#SBATCH --nodes=2

echo ""
echo "********************************************************************************"
echo "****************** Intel MPI 2018 -- Ping-pong test over RDMA ******************"
echo "********************************************************************************"
echo ""
# Intel 2018
# !NOTE: CentOS 7.9 users shm:ofa not shm:dapl
export INTELMPI_ROOT=/opt/intel/impi/2018.4.274
export I_MPI_FABRICS=shm:ofa
export I_MPI_ROOT=/opt/intel/compilers_and_libraries/linux/mpi
source /opt/intel/impi/2018.4.274/bin64/mpivars.sh

mpirun IMB-MPI1 pingpong

echo ""
echo "********************************************************************************"
echo "****************** Intel MPI 2021 -- Ping-pong test over RDMA ******************"
echo "********************************************************************************"
echo ""
# Intel 2021
export INTELMPI_ROOT=/opt/intel/oneapi/mpi/2021.2.0
export I_MPI_FABRICS=shm:ofi
export I_MPI_OFI_PROVIDER=mlx
# !!IMPORTANT: FI_PROVIDER=verbs is less performant than mlx! 
export FI_PROVIDER=mlx I_MPI_OFI_EXPERIMENTAL=1
export I_MPI_ROOT=/opt/intel/oneapi/mpi/2021.2.0
module load mpi/impi_2021.2.0
source /opt/intel/oneapi/mpi/2021.2.0/etc/conda/activate.d/mpivars.activate.sh

/opt/intel/oneapi/mpi/2021.2.0/bin/mpirun IMB-MPI1 pingpong