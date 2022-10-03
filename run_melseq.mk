# melseq_prism main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#


####################################################################
# this used by the interactive script to sequence a run of all steps
####################################################################

%.run_all: %.run_html
	date > $@

%.run_html: %.run_kmer_analysis
	$@.sh > $@.mk.log 2>&1
	date > $@

%.run_kmer_analysis: %.run_summarise
	$@.sh > $@.mk.log 2>&1
	date > $@

%.run_summarise: %.run_blast
	$@.sh > $@.mk.log 2>&1
	date > $@

%.run_blast: %.run_format
	$@.sh > $@.mk.log 2>&1
	date > $@

%.run_format: %.run_trim 
	$@.sh > $@.mk.log 2>&1
	date > $@

%.run_trim: %.run_demultiplex
	$@.sh > $@.mk.log 2>&1
	date > $@

%.run_demultiplex:
	$@.sh > $@.mk.log 2>&1
	date > $@


##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.run_all %.run_kmer_analysis %.run_summarise %.run_blast %.run_format %.run_trim %.run_demultiplex 

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

