#!/usr/bin/env python
import sys
import os
import re


# fasta text is streamed in , and each sequence name is edited using the 
# command line argument, which is a sample filename like
# 961498_AACCAGTCA_psti.R1.fastq_trimmed.fastq.gz
# yields e.g.
#>B74231_CTACAGA_psti.000000001 D00390:318:CB6K1ANXX:5:2302:1489:2053
#TGCAGAACGTGGCACAGAATGGTGACCACATCATTGCTGC
# etc

def main():
    sample_file_name = sys.argv[1]
    match = re.match("^([^\.]+)\.", os.path.basename(sample_file_name))
    if match is None:
        raise Exception("unable to parse sample id from %s"%os.path.basename(sample_file_name))
    sample = match.groups()[0]
 
    seq_number = 1
    for record in sys.stdin:
        match = re.match("^>(\S+)", record )
        if match is not None:
            illumina_moniker = match.groups()[0]
            sys.stdout.write(">%s.%09d %s\n"%(sample, seq_number, illumina_moniker))
            seq_number += 1
        else:
            sys.stdout.write(record)

if __name__ == "__main__":
   main()

