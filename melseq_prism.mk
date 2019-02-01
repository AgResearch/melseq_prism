# melseq_prism main makefile
#***************************************************************************************
# references:
#***************************************************************************************
# make: 
#     http://www.gnu.org/software/make/manual/make.html
#


##############################################
# how to make kmer spectra
##############################################
%.demultiplex:
	$@.sh
	date > $@

%.trim:
	$@.sh
	date > $@

%.format:
	$@.sh
	date > $@

%.blast:
	$@.sh
	date > $@

%.kmer_analysis:
	$@.sh
	date > $@

%.summarise:
	$@.sh
	date > $@

##############################################
# specify the intermediate files to keep 
##############################################
.PRECIOUS: %.log %.demultiplex %.trim

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

