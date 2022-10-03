# melseq_prism main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#


##############################################
# how to make individual targets, but no dependency 
##############################################
%.html:
	$@.sh > $@.mk.log 2>&1
	date > $@

%.demultiplex:
	$@.sh > $@.mk.log 2>&1
	date > $@

%.trim:
	$@.sh > $@.mk.log 2>&1
	date > $@

%.format:
	$@.sh > $@.mk.log 2>&1
	date > $@

#note that this merge_lanes target did a simple concatenation of the non-redundant fasta files. Although this worked and passed testing, it had a couple of bugs (
#(1) resulting fasta file has different seqs with the same name, (2) resulting fasta file was no longer "non-redundant". So this target 
#is deprecated , and no longer part of the pipeline. Merging of lanes now done as part of the trimming step, by piping both lanes to cutadapt  
%.merge_lanes:
	$@.sh > $@.mk.log 2>&1
	date > $@

%.blast:
	$@.sh > $@.mk.log 2>&1
	date > $@

%.kmer_analysis:
	$@.sh > $@.mk.log 2>&1
	date > $@

%.summarise:
	$@.sh > $@.mk.log 2>&1
	date > $@

##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS:  %.demultiplex %.trim %.format %.blast %.kmer_analysis %.summarise

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

