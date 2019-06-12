#!/usr/bin/env python
from __future__ import print_function
import sys, os, re, argparse


def create_links(args):
    # read in tke name/link key valus
    with open(args["key_value_file"], "r") as key_values:
        key_value_dict = dict( [ re.split("\t", record.strip()) for record in key_values if len(re.split("\t", record.strip())) == 2 ]  )
        keys=set(key_value_dict.keys())
        replicate = dict(zip(keys, len(keys) * [1]))
        
    for path in args['file_names']: 
        if not os.path.isfile(path):
            print("warning %s is not a file - ignoring"%path)
            continue

        path_tokens = set(re.split("[\s\/_]", path.strip()))

        intersect = path_tokens.intersection(keys)
        
        if len(intersect) == 0:
            print("warning , no match for %s in %s"%(path, args["key_value_file"]))
        elif len(intersect) > 1:
            print("warning , multiple matches for %s in %s"%(path, args["key_value_file"]))
        else:
            key=intersect.pop()
            link_base=args["pattern"]%(key_value_dict[key] , replicate[key])
            link_path=os.path.join(os.path.dirname(path), link_base)
            if os.path.exists(link_path):
                replicate[key] += 1
                link_base=args["pattern"]%(key_value_dict[key] , replicate[key])
                link_path=os.path.join(os.path.dirname(path), link_base)        
            if args["dry_run"]:
                print("will create a link %s pointing to %s"%(link_path, path))
            else:
                os.symlink(path, link_path)
                
    

def get_options():
    description = """
    """
    long_description = """

This script is used to create links to results files, using a key value dictionary

Where the link-to-file is many to one - i.e. replicates - the link name will be adjusted
using a replicate number 

key_value_file is tab delimited and contains e.g.

SampleID	Label
961186	B75104
961376	B70822
961382	B72188
961455	B73844
961458	B73777

pattern is a pattern for the link names, for example

"%s_summary.txt"

example:

dry run :

./link_samples.py -n -k sample_to_subject.txt -p "%s.%d_summary.txt"  /dataset/gseq_processing/scratch/melseq/SQ0990/cattle/summary/*.summary

then 

./link_samples.py -k sample_to_subject.txt -p "%s.%d_summary.txt"  /dataset/gseq_processing/scratch/melseq/SQ0990/cattle/summary/*.summary


    """
    parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
    parser.add_argument('file_names', type=str, nargs='+',metavar="filename", help='list of files to link to')
    parser.add_argument('-k', '--key_value_file' , dest='key_value_file', required=True, type=str, help="key value file")
    parser.add_argument('-p', '--pattern' , dest='pattern', default="%s.%d.summary.txt", type=str, help="link pattern - should allow for a link base and replciate / version number")
    parser.add_argument('-n', '--dry_run' , dest='dry_run', action='store_true', default = False , help="dry run  - display links but don't do them")
              
    args = vars(parser.parse_args())

    if not os.path.isfile(args["key_value_file"]):
        raise Exception("error %s does not exist"%args["key_value_file"])
    
    return args

def main():
    args=get_options()
    create_links(args)


if __name__ == "__main__":
   main()

