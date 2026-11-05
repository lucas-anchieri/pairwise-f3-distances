#!/bin/bash -l

#SBATCH --job-name process_outgroup-f3
#SBATCH --mail-type ALL
#SBATCH --mail-user lucas.anchieri@unil.ch

#SBATCH --partition cpu

#SBATCH --nodes 1
#SBATCH --ntasks 1
#SBATCH --cpus-per-task 1
#SBATCH --mem 8G
#SBATCH --time 01:00:00

module add r-light

INPUT_PATH=$1
SCRIPT_DIR=$2
PREFIX=${INPUT_PATH##*'/'}

outfiles=`ls $SCRATCH/outgroup-f3/$PREFIX/*_*/*.out`
outfile_all=$INPUT_PATH.f3
n_files=`echo $outfiles | wc -l`

echo "Source1              Source2                Target           f_3        std_err           Z    SNPs" > $outfile_all

for ((i=0; i<=$n_files; i+=250)); do
  cat `echo $outfiles | tail -n +$i | head -n 250` | cut -d ':' -f 2- | sed 's/^ *//g' >> $outfile_all
done

Rscript $SCRIPT_DIR/05_distance_matrix.R $INPUT_PATH