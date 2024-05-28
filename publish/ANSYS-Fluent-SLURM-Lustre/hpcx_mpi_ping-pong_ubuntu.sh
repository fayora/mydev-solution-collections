#!/bin/bash
#SBATCH --job-name=mpi_ping-pong
#SBATCH --nodes=2

echo ""
echo "====================================================="
echo "HPCX:"
echo "====================================================="
echo ""

module load mpi/hpcx

echo "~~~~~~~~~~~~~~~~ LATENCY TEST ~~~~~~~~~~~~~~~~~~~~~~~"
mpirun --map-by node -x LD_LIBRARY_PATH $HPCX_OSU_DIR/osu_latency
echo ""

echo "~~~~~~~~~~~~~~~~ BANDWIDTH TEST ~~~~~~~~~~~~~~~~~~~~~"
mpirun --map-by node -x LD_LIBRARY_PATH $HPCX_OSU_DIR/osu_bw
echo ""

module unload mpi

echo ""
echo "====================================================="
echo "HPCX-PMIX:"
echo "====================================================="
echo ""

module load mpi/hpcx-pmix

echo "~~~~~~~~~~~~~~~~ LATENCY TEST ~~~~~~~~~~~~~~~~~~~~~~~"
mpirun --map-by node -x LD_LIBRARY_PATH $HPCX_OSU_DIR/osu_latency
echo ""

echo "~~~~~~~~~~~~~~~~ BANDWIDTH TEST ~~~~~~~~~~~~~~~~~~~~~"
mpirun --map-by node -x LD_LIBRARY_PATH $HPCX_OSU_DIR/osu_bw
echo ""

module unload mpi




