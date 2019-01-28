#!/bin/bash

# this is based on /dataset/GBS_Rumen_Metagenomes/active/bin/run1.sh

export SEQ_PRISMS_BIN=/dataset/gseq_processing/active/bin/melseq_prism/seq_prisms 

DATA_DIR=/bifo/scratch/GBS_Rumen_Metagenomes/toBlastPstI  
OUT_DIR=/dataset/gseq_processing/scratch/melseq
REF=/dataset/GBS_Rumen_Metagenomes/scratch/blast_analysis/GenusPlusQuinella

function blast() {
   folder=$1
   file_pattern=$2
   mkdir -p $OUT_DIR/${folder}
   time $SEQ_PRISMS_BIN/align_prism.sh -f -a blastn -r $REF -p "-num_threads 4 -outfmt \'6 std qlen \' -evalue 0.02"  -O $OUT_DIR/${folder} $DATA_DIR/*${file_pattern}.fa 1>$OUT_DIR/${folder}/run1.blast.stdout 2>$OUT_DIR/${folder}/run1.blast.stderr
   #real    0m43.802s
   #user    0m2.364s
   #sys     0m0.525s
}

function summarise() {
   folder=$1
   rm summary_commands.txt

   # generate command file 
   for result_file in $OUT_DIR/${folder}/*.results.gz ; do
      base=`basename $result_file .results.gz`
      dir=`dirname $result_file`
      echo "gunzip -c $result_file  > $dir/$base.resultsNucl ; Rscript --vanilla $SEQ_PRISMS_BIN/../summarizeR_counts.code $dir/$base.resultsNucl 1>$dir/$base.resultsNucl.stdout 2>$dir/$base.resultsNucl.stderr; rm $dir/$base.resultsNucl" >> summary_commands.txt
   done
   time tardis -c 1 --shell-include-file etc/r_env.include source _condition_text_input_summary_commands.txt
}

function summmarise_kmers() {
   folder=$1
   file_pattern=$2
   mkdir -p $OUT_DIR/${folder}_kmers
   $SEQ_PRISMS_BIN/kmer_prism.sh  -p "--weighting_method tag_count -k 6" -O $OUT_DIR/${folder}_kmers $DATA_DIR/*${file_pattern}.fa 
}


blast toBlastPstI _toBLAST
summarise toBlastPstI  
