#!/usr/bin/env python
from __future__ import print_function
import sys
import os
import re


# make a version of heading with readable headings
# e.g. SQ1917_HGT5JDRX2_s_merged_fastq.txt.gz.demultiplexed_966045_CAACTGACTG_psti.R1_trimmed.fastq.non-redundant.fasta.blastn.GTDB1.num_threads4taskblastnword_size16outfmt6stdqlen
#evalue0.02.summary.taxonomy.pickle
#to
#966045_CAACTGACTG_psti


def main():
    record_count=0
    for record in sys.stdin:
        record_count += 1
        if record_count == 1:
            fields = re.split("\t", record.strip())
            edited_fields=[]
            for field in fields:
                match=re.search("\.demultiplexed_([^\.]+)\.R1_trimmed", field)
                if match is not None:
                    edited_fields.append(match.groups()[0])
                else:
                    edited_fields.append(field)

            print("\t".join(edited_fields))
        else:
            print(record,end="")

if __name__ == "__main__":
   main()

