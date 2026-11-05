#!/bin/bash -l

#SBATCH --job-name outgroup-f3
#SBATCH --mail-type ALL
#SBATCH --mail-user lucas.anchieri@unil.ch

#SBATCH --partition cpu

#SBATCH --nodes 1
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 1
#SBATCH --mem 8G
#SBATCH --time 01:00:00

INPUT_PATH=$1
n_iter=$2
PREFIX=${INPUT_PATH##*'/'}

# load necessary modules
module add gsl openblas
LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/dcsrsoft/spack/20260114/spack/opt/spack/linux-zen2/openblas-0.3.30-2zdddtfqumhpurf77s346jlt2yoiucu3/lib:/dcsrsoft/spack/20260114/spack/opt/spack/linux-zen2/gsl-2.8-3inpeaihyi3cjzqmv3lqu555uwjfutjq/lib/
export LD_LIBRARY_PATH

# define first and last indexes for current iteration
first_iteration=$((($SLURM_ARRAY_TASK_ID - 1) * $n_iter + 1))
last_iteration=$(($first_iteration + $n_iter - 1))
start_stop_iter=$first_iteration-$last_iteration
echo $start_stop_iter

# create corresponding directory in scratch
scratch_out=$SCRATCH/outgroup-f3/$PREFIX/${SLURM_ARRAY_TASK_ID}_${start_stop_iter}
outfile=$scratch_out/${SLURM_ARRAY_TASK_ID}_${start_stop_iter}.out
mkdir -p $scratch_out

# echo " Headers:             Source 1   s          Source 2               Target           f_3       std. err           Z    SNPs" > $outfile

for ((i=$first_iteration; i<=$last_iteration; i++)) {

  # isolate current pair
  head -n $i $INPUT_PATH.pairs | tail -n 1 > $scratch_out/f3_pops.list
  pair=`cat $scratch_out/f3_pops.list | cut -d ' ' -f 1,2 | sed "s/ /-/g"`

  # create parfile
  parfile=$scratch_out/$start_stop_iter.par
  echo genotypename:    $INPUT_PATH.geno > $parfile
  echo snpname:         $INPUT_PATH.snp >> $parfile
  echo indivname:       $INPUT_PATH.ind >> $parfile
  echo popfilename:     $scratch_out/f3_pops.list >> $parfile

  qp3Pop -p $parfile | tail -n 2 | head -n 1 >> $outfile
}

# grep -i err $outfile
# grep -i warn $outfile