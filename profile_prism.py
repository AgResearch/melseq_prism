#!/usr/bin/env python2.7
from __future__ import print_function

import itertools,os,re,argparse,string,sys
sys.path.append('/dataset/gseq_processing/active/bin/melseq_prism/seq_prisms')
from data_prism import prism, build, from_tab_delimited_file, bin_discrete_value


def my_taxonomy_tuple_provider(filename, *xargs):
    """
from a summary file like this :

Sequence11_count=1      Bacteria        Spirochaetes    Spirochaetia    Spirochaetales  Spirochaetaceae Treponema       Treponema bryantii
Sequence57_count=1      Bacteria        Firmicutes      Clostridia      Clostridiales   Lachnospiraceae Butyrivibrio    NA
Sequence62_count=1      Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      NA
Sequence89_count=1      Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      NA
Sequence106_count=1     Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      NA
Sequence114_count=1     Bacteria        Firmicutes      Clostridia      Clostridiales   Clostridiaceae  Sarcina NA
Sequence117_count=1     Archaea Euryarchaeota   Methanobacteria Methanobacteriales      Methanobacteriaceae     Methanobrevibacter      NA
Sequence142_count=1     Bacteria        Firmicutes      Clostridia      Clostridiales   Eubacteriaceae  Eubacterium     Eubacterium pyruvativorans
Sequence143_count=1     Bacteria        Firmicutes      Clostridia      Clostridiales   Lachnospiraceae Butyrivibrio    NA
Sequence147_count=1     Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      NA
Sequence175_count=1     Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      NA
Sequence188_count=2     Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      NA
Sequence188_count=2     Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      NA
Sequence197_count=1     Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      Prevotella brevis
Sequence302_count=2     Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      Prevotella brevis
Sequence302_count=2     Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      Prevotella brevis
Sequence311_count=1     Bacteria        Bacteroidetes   Bacteroidia     Bacteroidales   Prevotellaceae  Prevotella      NA

return a tuple of the first column, and othe columns as requested 
"""
    tuple_stream = from_tab_delimited_file(filename,0,*xargs[0:])   # pick which fields define the bins 

    atuple = tuple_stream.next()
    while True:
        yield ((atuple[0],"_".join(atuple[1:])))
        atuple = tuple_stream.next()



def my_value_provider(taxonomy_tuple, *xargs):
    weighting_method=xargs[0]

    if weighting_method == "line":
        return ((1, taxonomy_tuple[1]),)
    elif weighting_method == "parse":
        tokens=re.split("=", taxonomy_tuple[0])
        return ((int(tokens[1]), taxonomy_tuple[1]),)
    else:
        raise Exception("unexpected weightng method %s"%weighting_method)
    
            
def build_tax_distribution(datafile, weighting_method, columns, moniker):
    use_columns = [ int(item) for item in re.split(",", columns)]

    
    distob = prism([datafile], 1)

    #distob.DEBUG = True
    distob.file_to_stream_func = my_taxonomy_tuple_provider
    distob.file_to_stream_func_xargs = use_columns 
    distob.interval_locator_funcs = [bin_discrete_value]
    distob.spectrum_value_provider_func = my_value_provider
    distob.spectrum_value_provider_func_xargs = [weighting_method]
    
    distdata = build(distob,"singlethread")

    print("saving distribution to %s.taxonomy%s.pickle"%(datafile, moniker))
    distob.save("%s.taxonomy%s.pickle"%(datafile, moniker))
    print("""
    seq count %d
    taxonomy bin count %d
    
    """%(distob.total_spectrum_value, len(distob.spectrum.keys())))
    distob.list()
    
    return distdata

def locus_cmp(x,y):
    ord=cmp(x[0],y[0])
    if ord == 0:
        ord = cmp(x[1], y[1])
    return ord

def get_samples_tax_distribution(sample_tax_summaries, measure):
    tax_bins = [ prism.load(sample_tax_summary).get_spectrum().keys() for sample_tax_summary in sample_tax_summaries ]
    
    tax_bins =  list ( set(  reduce(lambda x,y:x+y, tax_bins ) ) ) 
    tax_bins.sort()


    if measure == "frequency":
        samples_tax_distributions = [[item[0] for item in tax_bins]] + [ prism.load(sample_tax_summary).get_raw_projection(tax_bins) for sample_tax_summary in sample_tax_summaries]

    else:
        samples_tax_distributions = [[item[0] for item in tax_bins]] + [ prism.load(sample_tax_summary).get_unsigned_information_projection(tax_bins) for sample_tax_summary in sample_tax_summaries]

    td_iter = itertools.izip(*samples_tax_distributions)
    heading = itertools.izip(*[["taxonomy"]]+[[re.split("\.",os.path.basename(path.strip()))[0]] for path in sample_tax_summaries])
    td_iter = itertools.chain(heading, td_iter)

    for record in td_iter:
        print(string.join([str(item) for item in record],"\t"))

def debug(options):
    #test_iter = my_taxonomy_tuple_provider(options["filenames"][0], *[5,6])
    test_iter = (my_value_provider(atuple, "line") for atuple in my_taxonomy_tuple_provider(options["filenames"][0], *[5,6]))
    #test_iter = (my_value_provider(atuple, "parse") for atuple in my_taxonomy_tuple_provider(options["filenames"][0], *[5,6]))

    for item in test_iter:
        print(item)


def get_options():
    description = """
    """
    long_description = """

example :

./profile_prism.py --weighting_method line /dataset/gseq_processing/scratch/melseq/SQ0990_S2311_L008_R1_sample_afm.fastq.gz/sheep/summary/*.summary

./profile_prism.py --weighting_method parse text.txt

./profile_prism.py --weighting_method line --columns 2,3,4 --moniker L1 /dataset/gseq_processing/scratch/melseq/SQ0990_S2311_L008_R1_sample_afm.fastq.gz/sheep/summary/*.summary

./profile_prism.py --summary_type summary_table --measure frequency /dataset/gseq_processing/scratch/melseq/SQ0990_S2311_L008_R1_sample_afm.fastq.gz/sheep/summary/*.pickle

./profile_prism.py --weighting_method line --columns 6 /dataset/gseq_processing/scratch/melseq/SQ0990/cattle/summary/*_summary.txt

./profile_prism.py --summary_type summary_table  --measure frequency /dataset/gseq_processing/scratch/melseq/SQ0990/cattle/summary/*_summary.txt.taxonomy.pickle > /dataset/gseq_processing/scratch/melseq/SQ0990/cattle/by_animal/html/taxonomy_genus_frequency_table.txt


"""

    parser = argparse.ArgumentParser(description=description, epilog=long_description, formatter_class = argparse.RawDescriptionHelpFormatter)
    parser.add_argument('filenames', type=str, nargs="*",help='input summary files (optionally compressed with gzip)')    
    parser.add_argument('--summary_type', dest='summary_type', default="sample_summaries", \
                   choices=["sample_summaries", "summary_table", "dump"],help="summary type (default: sample_summaries")
    parser.add_argument('--measure', dest='measure', default="frequency", \
                   choices=["frequency", "information"],help="measure (default: frequency")
    parser.add_argument('--columns' , dest='columns', default="5,6" ,help="comma separated list of columns to use to define bins")
    parser.add_argument('--moniker' , dest='moniker', default="" ,help="optional summmary moniker e.g. L1 L2 etc")    
    parser.add_argument('--weighting_method' , dest='weighting_method', default="parse",choices=["parse", "line"],help="weighting method - either parse weight from seq suffix, or just count lines")


    args = vars(parser.parse_args())
    return args

        
    
def main():
    args=get_options()

    #debug(args)
    #return

    if args["summary_type"] == "sample_summaries" :
        for filename in  args["filenames"]:
            tax_dist = build_tax_distribution(filename, weighting_method = args["weighting_method"], columns=args["columns"], moniker=args["moniker"])
            print(tax_dist)
            #write_summaries(filename,tax_dist)
    elif args["summary_type"] == "dump" :
        debug(args)
    elif args["summary_type"] == "summary_table" :
        #print "summarising %s"%str(args["filename"])
        get_samples_tax_distribution(args["filenames"], args["measure"])

    

    return

                                
if __name__ == "__main__":
   main()



        

