#!/bin/bash
#SBATCH --job-name=mpi_ping-pong
#SBATCH --nodes=2

# IMPORTANT: Check what version of Intel MPI 2021 is available on the nodes before running this script!!!
# ---> To check the version, run: 
#                                   module avail mpi/impi
IMPI_VERSION="2021.12"

# Similar latency and bandwidth tests for HPCX (OSU MPI Tests)
# mpirun --map-by node -x LD_LIBRARY_PATH $HPCX_OSU_DIR/osu_latency
# mpirun --map-by node -x LD_LIBRARY_PATH $HPCX_OSU_DIR/osu_bw


echo ""
echo "====================================================="
echo "INTEL MPI:"
echo "====================================================="
echo ""

module load mpi/impi_$IMPI_VERSION
source /opt/intel/oneapi/mpi/$IMPI_VERSION/etc/conda/activate.d/mpivars.activate.sh
mpirun IMB-MPI1 pingpong

module unload mpi

echo ""
echo "====================================================="
echo "HPCX:"
echo "====================================================="
echo ""

module load mpi/hpcx
source /opt/intel/oneapi/mpi/$IMPI_VERSION/etc/conda/activate.d/mpivars.activate.sh
mpirun IMB-MPI1 pingpong

module unload mpi

echo ""
echo "====================================================="
echo "HPCX-PMIX:"
echo "====================================================="
echo ""

module load mpi/hpcx-pmix
source /opt/intel/oneapi/mpi/$IMPI_VERSION/etc/conda/activate.d/mpivars.activate.sh
mpirun IMB-MPI1 pingpong

module unload mpi

echo ""
echo "====================================================="
echo "INTEL MPI: over Ethernet/TCP"
echo "====================================================="
echo ""

module load mpi/impi_$IMPI_VERSION
source /opt/intel/oneapi/mpi/$IMPI_VERSION/etc/conda/activate.d/mpivars.activate.sh
export FI_PROVIDER=tcp
export I_MPI_OFI_PROVIDER=tcp
export FI_TCP_IFACE=eth0
mpirun IMB-MPI1 pingpong

module unload mpi