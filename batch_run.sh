#!/bin/bash

# this is based on /dataset/GBS_Rumen_Metagenomes/active/bin/run1.sh

export SEQ_PRISMS_BIN=/dataset/gseq_processing/active/bin/melseq_prism/seq_prisms 

DATA_DIR=/bifo/scratch/GBS_Rumen_Metagenomes/toBlastApeKI  
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

function patch_blast() {
   folder=$1
   for file_base in 961023_AGAACGT_psti_toBLAST.fa 961064_TTGTTGACA_psti_toBLAST.fa 961109_GAGGCTG_psti_toBLAST.fa 961110_CCTCGCA_psti_toBLAST.fa 961111_TTCGAAG_psti_toBLAST.fa 961113_CCGAATA_psti_toBLAST.fa 961115_ACTACGA_psti_toBLAST.fa 961161_TTGCTACCA_psti_toBLAST.fa 961162_CCTCGTACA_psti_toBLAST.fa 961163_TTCGACGCA_psti_toBLAST.fa; do
      set -x
      rm $OUT_DIR/${folder}_results/${file_base}*
      set +x
      time $SEQ_PRISMS_BIN/align_prism.sh -f -a blastn -r $REF -p "-num_threads 4 -outfmt \'6 std qlen \' -evalue 0.02"  -O $OUT_DIR/${folder}_results $DATA_DIR/$file_base 1>$OUT_DIR/${folder}_results/run1.patch_blast.stdout 2>$OUT_DIR/${folder}_results/run1.patch_blast.stderr
   done
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

function patch_summarise() {
   folder=$1
   rm summary_commands.txt

   # generate command file
   for file_base in 961023_AGAACGT_psti_toBLAST.fa 961064_TTGTTGACA_psti_toBLAST.fa 961109_GAGGCTG_psti_toBLAST.fa 961110_CCTCGCA_psti_toBLAST.fa 961111_TTCGAAG_psti_toBLAST.fa 961113_CCGAATA_psti_toBLAST.fa 961115_ACTACGA_psti_toBLAST.fa 961161_TTGCTACCA_psti_toBLAST.fa 961162_CCTCGTACA_psti_toBLAST.fa 961163_TTCGACGCA_psti_toBLAST.fa; do
      for result_file in $OUT_DIR/${folder}_results/${file_base}*.results.gz ; do
         base=`basename $result_file .results.gz`
         dir=`dirname $result_file`
         echo "gunzip -c $result_file  > $dir/$base.resultsNucl ; Rscript --vanilla $SEQ_PRISMS_BIN/../summarizeR_counts.code $dir/$base.resultsNucl 1>$dir/$base.resultsNucl.stdout 2>$dir/$base.resultsNucl.stderr; rm $dir/$base.resultsNucl" >> summary_commands.txt
      done
   done
   time tardis -c 1 --shell-include-file r_env.include source _condition_text_input_summary_commands.txt
}

function summmarise_kmers() {
   folder=$1
   file_pattern=$2
   mkdir -p $OUT_DIR/${folder}_kmers
   $SEQ_PRISMS_BIN/kmer_prism.sh  -p "--weighting_method tag_count -k 6" -O $OUT_DIR/${folder}_kmers $DATA_DIR/*${file_pattern}.fa 
}


#blast toBlastApeKI _toBLAST
summarise toBlastApeKI  
#patch_blast 181212
#patch_summarise 181212 
#summmarise_kmers 181212 _toBLAST 
