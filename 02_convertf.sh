#!/bin/bash -l

#SBATCH --job-name convertf
#SBATCH --mail-type ALL
#SBATCH --mail-user lucas.anchieri@unil.ch

#SBATCH --partition cpu

#SBATCH --nodes 1
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 1
#SBATCH --mem 8G
#SBATCH --time 01:00:00

CONVERTF_PAR=$1

# load necessary modules
module add gsl openblas
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/dcsrsoft/spack/20260114/spack/opt/spack/linux-zen2/openblas-0.3.30-2zdddtfqumhpurf77s346jlt2yoiucu3/lib:/dcsrsoft/spack/20260114/spack/opt/spack/linux-zen2/gsl-2.8-3inpeaihyi3cjzqmv3lqu555uwjfutjq/lib/
export LD_LIBRARY_PATH

convertf -p $CONVERTF_PAR