# F3-DIST v1.0
These scripts allow for automatised computation of pairwise outgroup-f<sub>3</sub> statistics and 1–f<sub>3</sub> distances for a given dataset. The scripts are adapted to the slurm scheduling system of the _curnagl_ HPC at the University of Lausanne to run jobs in parallel, but can easily be adapted to slurm instances in other HPC or to other job scheduling systems.

The pipeline requires `admixtools` and `convertf` to be installed and added to the path. In addition, it requires `python` with the `sys` and `itertools` packages, as well as `R` with the `data.table`, `tidyverse`, and `reshape2` libraries.

The pipeline accepts `.bed` or `.geno` files as input. If a `.bed` file is provided, it will first be converted to `.geno` using `convertf`.

`F3-DIST` will automatically split the computations of outgroup-f<sub>3</sub> stats between parallel jobs in a way that is optimized as to be scalable for large datasets. For a dataset comprising _N_ individuals, _C = N * (N – 1) / 2_ stats in total will be computed. The computations will be split between _J = N – 1_ (if _N_ is even) or _J = N_ (if _N_ is odd) parallel jobs, each computing _C / K_ outgroup-f<sub>3</sub> stats in a for loop using `admixtools`. This ensures to keep both the amount of computations per job and the amount of parallel jobs to a minimum.

The resulting _f<sub>3</sub>_ stats will be parsed, 1–f<sub>3</sub> distances computed, and each pair if fewer than 2,000 overlapping SNPs will be set to NA. This number cannot be changed from the command line yet, but I plan to add this option in the future. For now, it can be changed by manually setting the threshold at line 15 of the `05_distance_matrix.R` script to a different number. The 1–f<sub>3</sub> distances are then stored in a matrix and saved. In order to build a pairwise distance matrix without missing data, the matrix is parsed for `NA` values, and the individual with the most `NA` is removed iteratively until no missing value remains in the matrix.

## Installation
No installation is required as long as the necessary software are there, as this is just a collection of bash, python, and R scripts. A symlink to the `F3-DIST` executable bash script can be added to the path in order to allow calling the script from any location.
```
ln -s /path/to/F3-DIST ~/.local/bin/F3-DIST
```

## Usage
`F3-DIST` should be called using the `--input` or `-i` flag to set the path of the dataset, and the `--outgroup` or `-o` flag to set which of the populations in the dataset should be considered the outgroup:
```
F3-DIST --input /path/to/dataset.bed --outgroup Yoruba
```

When providing a dataset in `.bed` format, the scripts will look for the outgroup in the first column of the `.fam` file. When computing pairwise outgroup-f<sub>3</sub> statistics between individuals, one should make sure that each individual has a different FID in the first column of the`.fam` file, except for the individuals that are part of the outgroup, which should all have the label specified with the `--outgroup` flag as the FID. When providing a dataset in `.geno` format, the same applies to the third column of the `.ind` file.

Temporary files will be stored by default in `./f3dist_tmp/`. This can be changed for a single run with the `--temp-path` flag, or the default temp files path can be changed for all future runs with the flag `--temp-default`.

## Output
`F3-DIST` outputs 2 files, saved in the same directory as the input dataset:

`<dataset>.f3`: a concatenation of the raw `admixtools` output for all _C_ combinations of individuals, including _f<sub>3</sub>_ stat, standard error, Z-score, and number of overlapping SNPs.

`<dataset>.f3.dist`: a _N x N_ matrix containting the 1–f<sub>3</sub> distance values for each pair of individuals.
