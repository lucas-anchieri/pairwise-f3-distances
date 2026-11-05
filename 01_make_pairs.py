#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys
from itertools import combinations

popfile = sys.argv[1]
pairsfile = sys.argv[1][:-4] + ".pairs"

f=open(popfile, 'r') #ancient pops name
fout = open(pairsfile, 'w')
ancientpops = f.read().splitlines()

comb = combinations(ancientpops, 2)

allcomb = list(comb)

# Print the obtained combinations
for combs in allcomb:
    fout.writelines(" ".join(combs)+ " Yoruba\n")