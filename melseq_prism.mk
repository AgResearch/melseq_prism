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
	$@.sh > $@.mk.log 2>&1
	date > $@

%.trim:
	$@.sh > $@.mk.log 2>&1
	date > $@

%.format:
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
.PRECIOUS: %.log %.demultiplex %.trim

##############################################
# cleaning - not yet doing this using make  
##############################################
clean:
	echo "no clean for now" 

