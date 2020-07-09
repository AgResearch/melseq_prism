#!/bin/bash
#
# get counts of numbers of samples in and out of each step
#

MELSEQ_PRISM_BIN=/dataset/gseq_processing/active/bin/melseq_prism

function get_opts() {

   DRY_RUN=no
   help_text="
\n
check_processing.sh [-h] [-n] processing_folder \n
example:\n
check_processing.sh /dataset/gseq_processing/scratch/melseq/SQ1324_CE9U7ANXX\n
\n
"

   # defaults:
   while getopts ":nh" opt; do
   case $opt in
       n)
         DRY_RUN=yes
         ;;
       h)
         echo -e $help_text
         exit 0
         ;;
       \?)
         echo "Invalid option: -$OPTARG" >&2
         exit 1
         ;;
       :)
         echo "Option -$OPTARG requires an argument." >&2
         exit 1
         ;;
     esac
   done

   shift $((OPTIND-1))

   processing_folder=$1

}


function check_opts() {
   if [ ! -d "$processing_folder" ]; then
      echo "processing folder $processing_folder not found"
      exit 1
   fi
}

function echo_opts() {
  echo DRY_RUN=$DRY_RUN
}


function check_demultiplex() {
   echo "file demultiplex_count" | awk '{printf("%s\t%s\n",$1,$2);}' -
   for file in $processing_folder/demultiplex/*.demultiplexed/*.fastq.gz; do
      count=`/stash/miniconda3/envs/universal2/bin/kseq_count $file`
      echo "$file $count" | awk '{printf("%s\t%d\n",$1,$2);}' - 
   done
}

function check_trimming() {
   echo "trim_processed trim_written" | awk '{printf("%s\t%s\n",$1,$2);}' - 
   for file in $processing_folder/demultiplex/*.demultiplexed/*.fastq.gz; do
      base=`basename $file .fastq.gz`
      trimfile=`ls $processing_folder/trimming/*${base}*.trimReport`
      if [ -f "$trimfile" ]; then
         cat $trimfile | $MELSEQ_PRISM_BIN/parse_trim.py 
      fi
   done
}

function check_fasta() {
   echo "fastafile fasta_count" | awk '{printf("%s\t%s\n",$1,$2);}' -
   for file in $processing_folder/demultiplex/*.demultiplexed/*.fastq.gz; do
      base=`basename $file .fastq.gz`
      fastafile=`ls $processing_folder/fasta/*${base}*.non-redundant.fasta`
      if [ -f "$fastafile" ]; then
         count=`cat $fastafile | ./count_non_redundant_fasta.py`
         echo "$fastafile $count" | awk '{printf("%s\t%d\n",$1,$2);}' -
      fi
   done
}

function check_blast() {
   echo "blastfile blast_count" | awk '{printf("%s\t%s\n",$1,$2);}' -
   for file in $processing_folder/demultiplex/*.demultiplexed/*.fastq.gz; do
      base=`basename $file .fastq.gz`
      blastfile=`ls $processing_folder/blast/*${base}*.results.gz`
      if [ -f "$blastfile" ]; then
         count=`gunzip -c  $blastfile | awk '{print $1}' | sort -u | ./count_blast.py`
         echo "$blastfile $count" | awk '{printf("%s\t%d\n",$1,$2);}' -
      fi
   done
}

function check_summary() {
   echo "summaryfile summary_count" | awk '{printf("%s\t%s\n",$1,$2);}' -
   for file in $processing_folder/demultiplex/*.demultiplexed/*.fastq.gz; do
      base=`basename $file .fastq.gz`
      summaryfile=`ls $processing_folder/summary/*${base}*.summary`
      if [ -f "$summaryfile" ]; then
         count=`wc -l  $summaryfile | awk '{print $1}' -`
         echo "$summaryfile $count" | awk '{printf("%s\t%d\n",$1,$2);}' -
      fi
   done
}

function main() {
   get_opts "$@"
   check_opts
   echo_opts
   set -x
   check_demultiplex >  $processing_folder/demultiplex_counts.txt
   check_trimming >  $processing_folder/trimming_counts.txt
   check_fasta > $processing_folder/fasta_counts.txt
   check_blast > $processing_folder/blast_counts.txt
   check_summary > $processing_folder/summary_counts.txt
   paste $processing_folder/demultiplex_counts.txt $processing_folder/trimming_counts.txt $processing_folder/fasta_counts.txt $processing_folder/blast_counts.txt $processing_folder/summary_counts.txt > $processing_folder/processing_counts.txt
}


main "$@"

