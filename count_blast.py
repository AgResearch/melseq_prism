#!/bin/env pypy
from __future__ import print_function
import re, sys
import itertools

def count_iter():
    tuple_iter = (tuple(re.split("\s+", record.strip())) for record in sys.stdin  if len(record.strip()) > 0)
    for my_tuple in tuple_iter:
        yield int(re.split("=", my_tuple[0])[1])

print(sum(count_iter()))
