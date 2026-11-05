#!/bin/bash -l

echo F3-DIST v1.0
echo "Usage: F3-DIST [--input|-i] <path/to/dataset> [--outgroup-o] <outgroup>"

# getting the path of the scripts that are used
SCRIPT_DIR=$(dirname -- "$(readlink -f -- "$0")")

# default temp folder
TEMP_PATH=./f3dist_tmp

# parsing the arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -i|--input)
      INPUT_PATH="$2"
      echo "--input $INPUT_PATH"
      shift # past argument
      shift # past value
      ;;
    -o|--outgroup)
      OUTGROUP="$2"
      echo "--outgroup $OUTGROUP"
      shift # past argument
      shift # past value
      ;;
    -t|--temp-path)
      TEMP_PATH="$2"
      echo "--scratch $TEMP_PATH"
      shift # past argument
      shift # past value
      ;;
    -T|--temp-default)
      NEW_TEMP_PATH="$2"
      echo "--scratch_default $NEW_TEMP_PATH"
      echo "Setting default SCRATCH location to: $NEW_TEMP_PATH"
      sed -i "s/${TEMP_PATH//\//\\/}/${NEW_TEMP_PATH//\//\\/}/g" $SCRIPT_DIR/$0
      exit 0
      ;;
    -*|--*)
      echo "Unknown option: $1"
      exit 1
      ;;
    *)
      echo "Unknown parameter: $1"
      exit 1
      ;;
  esac
done

# getting the prefix and extension of the dataset from the path
FILENAME=$(basename -- "$INPUT_PATH")
PREFIX=${FILENAME%'.'*}
EXT=${INPUT_PATH##*'.'}
INPUT_PATH_noEXT=${INPUT_PATH%'.'*}

# check whether input file is bed or geno, exit with error otherwise, and isolate list of individuals from .fam or .ind file
if [[ "$EXT" == "bed" ]]; then
  cat $INPUT_PATH_noEXT.fam | awk '{print $1}' | sort | uniq | grep -v $OUTGROUP > $INPUT_PATH_noEXT.pop
elif [[ "$EXT" == "geno" ]]; then
  cat $INPUT_PATH_noEXT.ind | awk '{print $3}' | sort | uniq | grep -v $OUTGROUP > $INPUT_PATH_noEXT.pop
else
   echo "ERROR: Unknown file extension: $EXT. Please provide a .bed or .geno file"
   exit 1
fi

# script to generate all possible pairs of individuals
$SCRIPT_DIR/01_make_pairs.py $INPUT_PATH_noEXT.pop

# combinatory wizardry to set the optimal way to split all the pairs between K job arrays each running L pairs in a loop
N_INDS=`wc -l < $INPUT_PATH_noEXT.pop`
N_COMBINATIONS=$(($N_INDS * ($N_INDS - 1) / 2))
if [ $((N_INDS%2)) -eq 0 ]; # check whether there is an even number of individuals
then
    N_PARALLELJOBS=$(($N_INDS - 1));
else
    N_PARALLELJOBS=$N_INDS;
fi
N_ITERATIONS=$(($N_COMBINATIONS / $N_PARALLELJOBS))

echo $N_INDS individuals in dataset
echo Running $N_PARALLELJOBS parallel jobs
echo each with a for loop computing $N_ITERATIONS f3-stats
echo for a total of $(($N_PARALLELJOBS * $N_ITERATIONS)) pairwise stats

# set up a temp output directory in scratch since we're generating a lot of files
TEMP_OUT=$TEMP_PATH/outgroup-f3/$PREFIX
mkdir -p $TEMP_OUT/logs
ln -nsf $TEMP_OUT scratch
ln -nsf $TEMP_OUT/logs logs_f3dist

# this variable will be used if the f3 job needs to depend on converft completion, but needs to be empty otherwise
CONVERTF_DEPENDENCY=""

# if input is in bed format, convert to geno
if [[ "$EXT" == "bed" ]]; then
  echo "Input is in .bed format. Converting to .geno using convertf."

  # reordering columns in fam file so that convertf works properly
  mv $INPUT_PATH_noEXT.fam $INPUT_PATH_noEXT.old.fam
  cat $INPUT_PATH_noEXT.old.fam | awk '{print $1, $2, $3, $4, $5, $1}' > $INPUT_PATH_noEXT.fam

  # setting up convertf parameter file
  echo genotypename:     $INPUT_PATH_noEXT.bed > $INPUT_PATH_noEXT.convertf.par
  echo snpname:          $INPUT_PATH_noEXT.bim >> $INPUT_PATH_noEXT.convertf.par
  echo indivname:        $INPUT_PATH_noEXT.fam >> $INPUT_PATH_noEXT.convertf.par
  echo outputformat:     PACKEDANCESTRYMAP >> $INPUT_PATH_noEXT.convertf.par
  echo genotypeoutname:  $INPUT_PATH_noEXT.geno >> $INPUT_PATH_noEXT.convertf.par
  echo snpoutname:       $INPUT_PATH_noEXT.snp >> $INPUT_PATH_noEXT.convertf.par
  echo indivoutname:     $INPUT_PATH_noEXT.ind >> $INPUT_PATH_noEXT.convertf.par
  echo familynames:      NO >> $INPUT_PATH_noEXT.convertf.par

  # run convertf
  jobID_convertf=$(sbatch --output $TEMP_OUT/logs/convertf_%j.out $SCRIPT_DIR/02_convertf.sh $INPUT_PATH_noEXT.convertf.par | cut - -d ' ' -f 4)
  echo Submitted convertf job: $jobID_convertf

  # set sbatch parameter so that the next job waits for convertf to be done. this variable will be empty if the if statement isn't run
  CONVERTF_DEPENDENCY="--depend=afterok:$jobID_convertf"
fi

# run script that computes f3 stats
jobID_f3=$(sbatch $CONVERTF_DEPENDENCY --array 1-$N_PARALLELJOBS --output $TEMP_OUT/logs/outgroup-f3_%A_%a.out $SCRIPT_DIR/03_outgroup_f3.sh $INPUT_PATH_noEXT $N_ITERATIONS | cut - -d ' ' -f 4)

echo Submitted outgroup-f3 job array: $jobID_f3

# process the f3 stats: compute 1-f3 for each pair and store the distance in a pairwise matrix
sbatch --depend=afterok:$jobID_f3 --output $TEMP_OUT/logs/process_f3_%j.out $SCRIPT_DIR/04_process_f3_output.sh $INPUT_PATH_noEXT $SCRIPT_DIR
