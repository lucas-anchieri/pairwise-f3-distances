#!/usr/bin/env Rscript
libraries <- c("data.table", "tidyverse", "reshape2")

suppressMessages(sapply(libraries, require, character.only = TRUE))

DATE <- Sys.Date()

#!/usr/bin/env Rscript
args = commandArgs(trailingOnly=TRUE)

# parse arguments
dataset_path <- args[1]

#loading pairwise outgroup-f3 statistics
f3_out <- fread(paste0(dataset_path, ".f3"), header = T, data.table = FALSE) |> filter(SNPs >= 2000)

# head(f3_out)

# making a matrix f3_out would only fill half of the square, so we need to prepare the other half as well
# creating a "mirror" dataframe with the same data but switching Source columns
f3_mirror <- f3_out
colnames(f3_mirror)[c(1, 2)] <- c("Source2", "Source1")

# merging f3_out and f3_mirror; now all individuals are represented in both columns
f3_square <- rbind(f3_out, f3_mirror)
f3_square$f3_dist <- 1 - f3_square$f_3
# head(f3_square)

# casting the dataframe into a matrix of 1-f3 distances, set the diagonal to 0
mat <- acast(f3_square, Source1 ~ Source2,
             value.var = 'f3_dist')
diag(mat) = 0
# mat[1:10, 1:10]

# removing the individual with the most missingness in a loop until no missing pairs remain
# condition on whether dimensions of the matrix with or without NAs are different
while (!all(dim(mat) == dim(na.omit(mat)))) {
  # list all missing pairs
  a <- which(is.na(mat), arr.ind=TRUE)

  # count how many times each individual appears in the missing pairs list
  all <- table(c(a[, "row"], a[, "col"]))
  # colnames(mat)[as.numeric(names(all[all == max(all)]))]

  # remove the individual that has the most missing pairs
  to_rm <- as.numeric(names(all[all == max(all)]))
  mat <- mat[-to_rm, -to_rm]
}

# write the distance matrix
fwrite(as.data.frame(mat), file = paste0(dataset_path, ".f3.dist"))
