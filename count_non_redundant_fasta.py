#!/bin/env pypy
from __future__ import print_function
import re, sys
import itertools

def fasta_iter():
    record_iter = (record.strip() for record in sys.stdin  if len(record.strip()) > 0)
    seq_group_iter = itertools.groupby(record_iter, lambda record:{True:"name", False:"seq"}[record[0] == ">"])
    name = None
    for (group, records) in seq_group_iter:
        if group == "name":
            yield int(re.split("=", records.next())[1])

print(sum(fasta_iter()))
