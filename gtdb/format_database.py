#!/usr/bin/env python
from __future__ import print_function
import sys
import os
import re
import argparse
sys.path.append('/dataset/bioinformatics_dev/active/data_prism') 
from data_prism import  get_text_stream

class format_database_exception(Exception):
    def __init__(self,args=None):
        super(format_database_exception, self).__init__(args)

def get_options():
    description = """
    """
    long_description = """
examples :

./format_database.py -t format_fasta /dataset/gseq_processing/scratch/melseq/gtdb/gtdb_genomes_reps_r207/GCA/001/775/355/GCA_001775355.1_genomic.fna.gz
./format_database.py -t format_taxonomy bac120_taxonomy_r207.tsv.gz ar53_taxonomy_r207.tsv.gz

    """
    parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
    parser.add_argument('inputfiles', type=str, nargs="*",help='input filename')
    parser.add_argument('-t', '--task' , dest='task', required=False, default="format_taxonomy" , type=str,
                        choices=["format_fasta", "format_taxonomy"], help="what you want to do")
    
    args = vars(parser.parse_args())

    return args

def format_fasta_entries(args):
    """
    a fasta file - e.g.
    
     GCF_012927245.1_genomic.fna.gz
    
     is opened and each sequence name is edited , for example
    
    >NZ_JABBGE010000001.1 etc
    needs to become
    
    >GTB1:GCF_012927245.1_JAFARC010000014.1 etc
    
     example :
     ./format_fasta_entries.py /dataset/gseq_processing/scratch/melseq/gtdb/gtdb_genomes_reps_r207/GCA/001/775/355/GCA_001775355.1_genomic.fna.gz 
    
    """
    seq_file = args["inputfiles"][0]
    
    match = re.match("^([^\.]+\.\d*)_", os.path.basename(seq_file))
    if match is None:
        raise Exception("unable to parse seq filename from %s"%os.path.basename(seq_file))
    accession = match.groups()[0]
 
    for record in get_text_stream(seq_file):
        match = re.match("^>(\S+)", record )
        if match is not None:
            sys.stdout.write(">GTDB1:%s_%s\n"%(accession, record.strip()[1:]))
        else:
            sys.stdout.write(record)

def format_taxonomy(args):
    """
from this : 
iramohio-01$ gunzip -c bac120_taxonomy_r207.tsv.gz | head
RS_GCF_000566285.1 d__Bacteria;p__Proteobacteria;c__Gammaproteobacteria;o__Enterobacterales;f__Enterobacteriaceae;g__Escherichia;s__Escherichia coli
RS_GCF_003460375.1 d__Bacteria;p__Proteobacteria;c__Gammaproteobacteria;o__Enterobacterales;f__Enterobacteriaceae;g__Escherichia;s__Escherichia coli
RS_GCF_008388435.1 d__Bacteria;p__Proteobacteria;c__Gammaproteobacteria;o__Enterobacterales;f__Enterobacteriaceae;g__Escherichia;s__Escherichia coli
RS_GCF_003000855.1 d__Bacteria;p__Proteobacteria;c__Gammaproteobacteria;o__Enterobacterales;f__Enterobacteriaceae;g__Escherichia;s__Escherichia coli

to this :

head /bifo/active/GBS_Rumen_Metagenomes/180727_Ajs_Samples/03_Analyses/Reference/SpeciesTaxonomy.csv
ID,Species,Genus,T_Kingdom,T_Phylum,T_Class,T_Order,T_Family,T_Genus,T_Species
Acetitomaculum_ruminis_DSM5522,Acetitomaculum ruminis,Acetitomaculum,Bacteria,Firmicutes,Clostridia,Clostridiales,Lachnospiraceae,Acetitomaculum,Acetitomaculum ruminis
Acidaminococcus_fermentans_pGA-4,Acidaminococcus fermentans,Acidaminococcus,Bacteria,Firmicutes,Negativicutes,Acidaminococcales,Acidaminococcaceae,Acidaminococcus,Acidaminococcus fermentans
Acidaminococcus_fermentans_WCC6,Acidaminococcus fermentens,Acidaminococcus,Bacteria,Firmicutes,Negativicutes,Acidaminococcales,Acidaminococcaceae,Acidaminococcus,Acidaminococcus fermentans
Acinetobacter_sp_DSM11652,Acinetobacter sp.,Acinetobacter,Bacteria,Proteobacteria,Gammaproteobacteria,Pseudomonadales,Moraxellaceae,Acinetobacter,NA
Actinomyces_denticolens_PA,Actinomyces denticolens,Actinomyces,Bacteria,Actinobacteria,Actinobacteria,Actinomycetales,Actinomycetaceae,Actinomyces,Actinomyces denticolens

(and remove the RB_|RS_ prefix ) 

"""

    print("ID,Species,Genus,T_Kingdom,T_Phylum,T_Class,T_Order,T_Family,T_Genus,T_Species")
    
    for tax_file in args["inputfiles"]:
        for record in get_text_stream(tax_file):
            (accession,taxonomy) = re.split("\t",record.strip())
            (division,phylum,clas,order,family,genus,species) = (item[3:] for item in re.split(";",taxonomy))
            print(",".join((accession[3:], species,genus,division,phylum,clas,order,family,genus,species)))
            

def main():
    options = get_options()
    #print("using %s"%str(options), file=sys.stderr)

    if options["task"] == "format_fasta":   # just matches pairs of files belonging to the same sample and concatenates them
        format_fasta_entries(options)
    elif options["task"] == "format_taxonomy":
        format_taxonomy(options)
    else:
        raise misc_task_exception("unsupported task %(task)s"%options)
    


if __name__ == "__main__":
   main()

