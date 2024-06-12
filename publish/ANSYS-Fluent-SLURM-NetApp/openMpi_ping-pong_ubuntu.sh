#!/bin/bash
#SBATCH --job-name=openMpi_ping-pong
#SBATCH --nodes=2

# !NOTE: it is a good idea to check what version of Intel MPI 2021 is available on the nodes before running this script
#        To check the version, run: module avail mpi/impi
IMPI_VERSION="2021.12"


echo ""
echo "====================================================="
echo "INTEL MPI: no variables set"
echo "====================================================="
echo ""
module load mpi/impi_$IMPI_VERSION
source /opt/intel/oneapi/mpi/$IMPI_VERSION/etc/conda/activate.d/mpivars.activate.sh
mpirun IMB-MPI1 pingpong


echo ""
echo "====================================================="
echo "INTEL MPI: with variables set"
echo "====================================================="
echo ""
export INTELMPI_ROOT=/opt/intel/oneapi/mpi/latest
export I_MPI_FABRICS=shm:ofi
export I_MPI_ROOT=/opt/intel/oneapi/mpi/latest

module load mpi/impi_$IMPI_VERSION
source /opt/intel/oneapi/mpi/$IMPI_VERSION/etc/conda/activate.d/mpivars.activate.sh
mpirun IMB-MPI1 pingpong

echo ""
echo "====================================================="
echo "INTEL MPI: over Ethernet/TCP"
echo "====================================================="
echo ""
export FI_PROVIDER=tcp
export I_MPI_OFI_PROVIDER=tcp
export FI_TCP_IFACE=eth0
mpirun IMB-MPI1 pingpong
