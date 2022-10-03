#!/bin/env python
from __future__ import print_function

import argparse
import time
import platform
import sys
import os
import re 


class generate_commands_exception(Exception):
    def __init__(self,args=None):
        super(generate_commands_exception, self).__init__(args)

def analyse_filenames(options):
    # open file of filenames and read into list

    # output dictionary as
    # mergedfile file1 file2 . . .
    with open(options["input_fof"][0], "r") as infiles:
        file_list = list( ( record.strip() for record in infiles ) )

    # process list, parse merged file and write to dictionary
    # example :
    # /dataset/GBS_Microbiomes_Processing/itmp/melseq/SQ1635/fasta/SQ1635_HCH3GDRXY_s_1_fastq.txt.gz.demultiplexed_966045_AGGCTAGGAT_psti.R1_trimmed.fastq.non-redundant.fasta
    # /dataset/GBS_Microbiomes_Processing/itmp/melseq/SQ1635/fasta/SQ1635_HCH3GDRXY_s_2_fastq.txt.gz.demultiplexed_966045_AGGCTAGGAT_psti.R1_trimmed.fastq.non-redundant.fasta
    # will be merged to make
    # /dataset/GBS_Microbiomes_Processing/itmp/melseq/SQ1635/fasta/SQ1635_HCH3GDRXY_fastq.txt.gz.demultiplexed_966045_AGGCTAGGAT_psti.R1_trimmed.fastq.merged.fasta
    

    merge_dict={}
    for filename in file_list:
        base = os.path.basename(filename)

        sample_match=re.match("^([^_]+)_", base)

        # we want to merge files for the same sample  - can't do this if can't parse a plausible sample name
        if sample_match is None:
            print("Could not find a plausible sample name in %s - giving up "%filename)
            sys.exit(1)
        sample=sample_match.groups()[0]

        # try to figure out a reasonable merge-file name
        merge_base=re.sub("_s_[1|2|3|4|5|6|7|8]_fastq","_s_merged_fastq",  base)
        if merge_base == base:
            # try using the parent folder - this may have the lane number
            dir_of_base = os.path.basename(os.path.dirname(filename))
            merge_dir_of_base=re.sub("_s_[1|2|3|4|5|6|7|8]_fastq","_s_merged_fastq",  dir_of_base)   # e.g. SQ1738_HWFLWDRXY_s_1_fastq.txt.gz.demultiplexed

            if merge_dir_of_base == dir_of_base:
                print("warning, could not match lane pattern in %s , so will use a with-lane name"%filename)
            else:
                merge_base = "%s_%s"%(merge_dir_of_base, base)  # e.g. SQ1738_HWFLWDRXY_s_merged_fastq.txt.gz.demultiplexed_978876_CTTAGTTGCA_psti.R1.fastq.gz
                merge_base = re.sub("R1\.fastq.gz$","R1_trimmed.fastq",merge_base)
                
        merge_file = os.path.join(options["mergedir"], merge_base)

        if (sample, merge_file) not in merge_dict:
            merge_dict[(sample, merge_file)] = [  filename ]
        else:
            merge_dict[(sample, merge_file)].append(filename)

    return merge_dict


def generate_commands(options):

    merge_dict = analyse_filenames(options)

    with open(options["output_file"],"w") as command_file:
        for (sample, merge_file) in merge_dict:
            print("cat %s > %s"%(" ".join(merge_dict[(sample, merge_file)]),merge_file), file=command_file)

def generate_merge_and_trim_commands(options):

    merge_dict = analyse_filenames(options)

    with open(options["output_file"],"w") as command_file:
        for (sample, merge_file) in merge_dict:
            # figure out report file name and stderr filename from merge_file
            report_file=re.sub("R1_trimmed.fastq$","R1.trimReport",merge_file)
            stderr_file=re.sub("R1_trimmed.fastq$","R1.stderr", merge_file)
            #print("tardis --hpctype slurm  --shell-include-file \$MELSEQ_PRISM_BIN/cutadapt_env.inc    -c 999999999 gunzip -c %s \| cutadapt -q 20  -m 40 -o %s - 1\> %s 2\>%s"%(" ".join(merge_dict[(sample, merge_file)]),merge_file,report_file,stderr_file), file=command_file)
            print("gunzip -c %s | cutadapt -q 20  -m 40 -o %s - 1> %s 2>%s"%(" ".join(merge_dict[(sample, merge_file)]),merge_file,report_file,stderr_file), file=command_file)


    

def get_options():
    description = """
    """
    long_description = """

Utility to help merge lanes from novaseq split-lanes. It generates the commands that would do the merge

examples :
#
# this is used for simply merging downstream files where the lane number is included in the file name, and the merge just concatenates the files
#
python merge_lanes.py -M /dataset/hiseq/scratch/postprocessing/melseq/SQ1738/merged_fasta -O /dataset/hiseq/scratch/postprocessing/melseq/SQ1738/merge_lanes_commands.txt /dataset/hiseq/scratch/postprocessing/melseq/SQ1738/merge_lanes_input_file_list.txt

would merge

/dataset/hiseq/scratch/postprocessing/melseq/SQ1738/fasta/SQ1738_HWFLWDRXY_s_1_fastq.txt.gz.demultiplexed_978876_CTTAGTTGCA_psti.R1_trimmed.fastq.non-redundant.fasta
/dataset/hiseq/scratch/postprocessing/melseq/SQ1738/fasta/SQ1738_HWFLWDRXY_s_2_fastq.txt.gz.demultiplexed_978876_CTTAGTTGCA_psti.R1_trimmed.fastq.non-redundant.fasta

to

/dataset/hiseq/scratch/postprocessing/melseq/SQ1738/merged_fasta/SQ1738_HWFLWDRXY_s_merged_fastq.txt.gz.demultiplexed_978876_CTTAGTTGCA_psti.R1_trimmed.fastq.non-redundant.fasta

#
# this is used for simultaneously trimming and merging upstream (i.e. demultiplex products) files (where the lane number is included in the parent folder file name) 
#
python merge_lanes.py -t generate_merge_trim_commands -M /dataset/hiseq/scratch/postprocessing/melseq/SQ1738/trimming  -O /dataset/hiseq/scratch/postprocessing/melseq/SQ1738/trim_and_merge_lanes_commands.txt /dataset/hiseq/scratch/postprocessing/melseq/SQ1738/trim_and_merge_lanes_input_file_list.txt

would generate commands to merge

/dataset/hiseq/scratch/postprocessing/melseq/SQ1738/demultiplex/SQ1738_HWFLWDRXY_s_1_fastq.txt.gz.demultiplexed/978876_CTTAGTTGCA_psti.R1.fastq.gz
/dataset/hiseq/scratch/postprocessing/melseq/SQ1738/demultiplex/SQ1738_HWFLWDRXY_s_2_fastq.txt.gz.demultiplexed/978876_CTTAGTTGCA_psti.R1.fastq.gz

to

/dataset/hiseq/scratch/postprocessing/melseq/SQ1738/trimming/SQ1738_HWFLWDRXY_s_merged_fastq.txt.gz.demultiplexed_978876_CTTAGTTGCA_psti.R1_trimmed.fastq


via

gunzip -c /dataset/hiseq/scratch/postprocessing/melseq/SQ1738/demultiplex/SQ1738_HWFLWDRXY_s_1_fastq.txt.gz.demultiplexed/978876_CTTAGTTGCA_psti.R1.fastq.gz
/dataset/hiseq/scratch/postprocessing/melseq/SQ1738/demultiplex/SQ1738_HWFLWDRXY_s_2_fastq.txt.gz.demultiplexed/978876_CTTAGTTGCA_psti.R1.fastq.gz |
cutadapt  -f fastq -q 20  -m 40 -
-o /dataset/hiseq/scratch/postprocessing/melseq/SQ1738/trimming/SQ1738_HWFLWDRXY_s_merged_fastq.txt.gz.demultiplexed_978876_CTTAGTTGCA_psti.R1_trimmed.fastq
1> /dataset/hiseq/scratch/postprocessing/melseq/SQ1738/trimming/SQ1738_HWFLWDRXY_s_merged_fastq.txt.gz.demultiplexed_978876_CTTAGTTGCA_psti.R1.trimReport
2> /dataset/hiseq/scratch/postprocessing/melseq/SQ1738/trimming/SQ1738_HWFLWDRXY_s_merged_fastq.txt.gz.demultiplexed_978876_CTTAGTTGCA_psti.R1.stderr

(where the per lane trimming would have generated

/dataset/hiseq/scratch/postprocessing/melseq/SQ1738/trimming/SQ1738_HWFLWDRXY_s_1_fastq.txt.gz.demultiplexed_978876_CTTAGTTGCA_psti.R1_trimmed.fastq
/dataset/hiseq/scratch/postprocessing/melseq/SQ1738/trimming/SQ1738_HWFLWDRXY_s_2_fastq.txt.gz.demultiplexed_978876_CTTAGTTGCA_psti.R1_trimmed.fastq

)
    """
    parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
    parser.add_argument('input_fof', type=str, nargs=1,help='file of input fasta or fastq filenames')
    parser.add_argument('-t', '--task' , dest='task', required=False, default="generate_commands" , type=str,
                        choices=["generate_commands", "generate_merge_trim_commands"], help="what you want to get / do")
    parser.add_argument('-O','--output_file', dest='output_file', type=str, default=None, help='output file to write commands to')
    parser.add_argument('-M','--mergedir', dest='mergedir', type=str, default=None, help='name of a folder where the merged files would be written')
    parser.add_argument('-a', '--adapter_phrase' , dest='adapter_phrase', required=False, default="" , type=str, help="adapter phrase to pass to cutadapt ")
    

    args = vars(parser.parse_args())

    if not os.path.isfile(args["input_fof"][0]):
        raise generate_commands_exception("%(input_fof)s is not a file"%args)


    return args


def main():
    options = get_options()
    print("using %s"%str(options), file=sys.stderr)

    if options["task"] == "generate_commands":   # just matches pairs of files belonging to the same sample and concatenates them
        generate_commands(options)
    elif options["task"] == "generate_merge_trim_commands": #
        generate_merge_and_trim_commands(options)
    else:
        raise generate_commands_exception("unsupported task %(task)s"%options)
        

if __name__=='__main__':
    sys.exit(main())    

    

        

