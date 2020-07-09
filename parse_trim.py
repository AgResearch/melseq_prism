#!/bin/env python
from __future__ import print_function
import re, sys

in_out=[None,None]
for record in sys.stdin:
    match = re.search("^Total reads processed:\s+(\S+)$", record.strip()) 
    if match is not None:
        in_out[0]=match.groups()[0].replace(",","")
    match = re.search("^Reads written \(passing filters\):\s+(\S+)\s\(", record.strip()) 
    if match is not None:
        in_out[1]=match.groups()[0].replace(",","")
        break
print("%s\t%s"%tuple(in_out))
