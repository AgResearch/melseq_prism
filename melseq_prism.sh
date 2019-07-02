#!/bin/bash

declare -a files_array

function get_opts() {

   DRY_RUN=no
   DEBUG=no
   HPC_TYPE=slurm
   OUT_DIR=
   MAX_TASKS=1
   FORCE=no
   ANALYSIS=demultiplex
   ENZYME_INFO=""
   taxonomy_blast_database=""
   taxonomy_lookup_file=
   seqlength_min=40
   seqqual_min=20
   similarity=0.02
   help_text="
\n
./melseq_prism.sh  [-h] [-n] [-d] -a analysis -b blast_database [-s similarity] [-m min_length] [-q min_qual]  [-C local|slurm ] -O outdir input_file_names\n
\n
\n
example:\n
./melseq_prism.sh -n -a all -l /dataset/gseq_processing/scratch/melseq/SQ0990_S2311_L008_R1_sample_afm.fastq.gz/sheep/sample_info.txt -b /dataset/GBS_Rumen_Metagenomes/scratch/blast_analysis/GenusPlusQuinella -O /dataset/gseq_processing/scratch/melseq/SQ0990_S2311_L008_R1_sample_afm.fastq.gz/sheep /dataset/gseq_processing/active/bin/melseq_prism/test/SQ0990_S2311_L008_R1_sample.fastq.gz \n
\n
./melseq_prism.sh -a html -O /dataset/gseq_processing/scratch/melseq/SQ0990_S2311_L008_R1_sample_afm.fastq.gz/sheep /dataset/gseq_processing/scratch/melseq/SQ0990_S2311_L008_R1_sample_afm.fastq.gz/sheep/\*.summary  \n
\n
./melseq_prism.sh -a html -O  /dataset/gseq_processing/scratch/melseq/SQ0990/sheep/by_sample \`ls /dataset/gseq_processing/scratch/melseq/SQ0990/sheep/summary/\*.summary | grep -v undetermined\` \n
\n
\n
./melseq_prism.sh -a html -O  /dataset/gseq_processing/scratch/melseq/SQ0990/sheep/by_animal \`ls /dataset/gseq_processing/scratch/melseq/SQ0990/sheep/summary/\*.summary.txt | grep -v undetermined\` \n
\n
 ./melseq_prism.sh  -a html -O /dataset/gseq_processing/scratch/melseq/SQ0990/cattle/by_animal \`ls /dataset/gseq_processing/scratch/melseq/SQ0990/cattle/summary/\*_summary.txt | grep -v undetermined\` \n
"

   # defaults:
   while getopts ":nhdfO:C:b:t:m:s:q:a:l:e:" opt; do
   case $opt in
       n)
         DRY_RUN=yes
         ;;
       d)
         DEBUG=yes
         ;;
       h)
         echo -e $help_text
         exit 0
         ;;
       f)
         FORCE=yes
         ;;
       a)
         ANALYSIS=$OPTARG
         ;;
       O)
         OUT_DIR=$OPTARG
         ;;
       C)
         HPC_TYPE=$OPTARG
         ;;
       e)
         ENZYME_INFO=$OPTARG
         ;;
       l)
         SAMPLE_INFO=$OPTARG
         ;;
       m)
         seqlength_min=$OPTARG
         ;;
       q)
         seqqual_min=$OPTARG
         ;;
       b)
         taxonomy_blast_database=$OPTARG
         ;;
       s)
         similarity=$OPTARG
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

   FILE_STRING=$@

   # this is needed because of the way we process args a "$@" - which 
   # is needed in order to parse parameter sets to be passed to the 
   # aligner (which are space-separated)
   declare -a files="(${FILE_STRING})";
   NUM_FILES=${#files[*]}
   for ((i=0;$i<$NUM_FILES;i=$i+1)) do
      files_array[$i]=${files[$i]}     
   done
}


function check_opts() {
   if [[ ( $ANALYSIS != "demultiplex" ) && ( $ANALYSIS != "trim" ) && ( $ANALYSIS != "format" ) && ( $ANALYSIS != "blast" ) && ( $ANALYSIS != "kmer_analysis" ) && ( $ANALYSIS != "summarise" )  && ( $ANALYSIS != "html" ) ]] ; then
      echo "analysis must be one of demultiplex, trim , format, blast, summarise , html, clean) "
      exit 1
   fi

   if [  -z "$OUT_DIR" ]; then
      echo "must specify OUT_DIR ( -O )"
      exit 1
   fi
   if [ ! -d $OUT_DIR ]; then
      echo "OUT_DIR $OUT_DIR not found"
      exit 1
   fi
   if [[ $HPC_TYPE != "local" && $HPC_TYPE != "slurm" ]]; then
      echo "HPC_TYPE must be one of local, slurm"
      exit 1
   fi
   if [ ! -z $taxonomy_blast_database ]; then
      if [ ! -f ${taxonomy_blast_database}.nin  ]; then
         echo "bad blast database (cant see ${taxonomy_blast_database}.nin ) (you might need to supply the full path ?)"
         exit 1
      fi
   fi
   python -c "print float('$similarity')" >/dev/null 2>&1
   if [ $? != 0 ]; then
      echo "looks like similarity requested ( $similarity ) is not a number"
      exit 1
   fi
   python -c "print float('$seqlength_min')" >/dev/null 2>&1
   if [ $? != 0 ]; then
      echo "looks like min seq length requested ( $seqlength_min ) is not a number"
      exit 1
   fi
   python -c "print float('$seqqual_min')" >/dev/null 2>&1
   if [ $? != 0 ]; then
      echo "looks like min seq qual requested ( $seqqal_min ) is not a number"
      exit 1
   fi
   if [ ! -f $SAMPLE_INFO ]; then
      echo "could not find $SAMPLE_INFO"
      exit 1
   fi

   if [ ! -z $ENZYME_INFO ]; then
      if [ ! -f $ENZYME_INFO ]; then
         echo "could not find $ENZYME_INFO"
         exit 1
      fi
   fi

}

function echo_opts() {
  echo OUT_DIR=$OUT_DIR
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo taxonomy_blast_database=$taxonomy_blast_database
  echo similarity=$similarity
  echo seqqal_min=$seqqal_min
  echo seqlength_min=$seqlength_min
  echo SAMPLE_INFO=$SAMPLE_INFO
  echo ENZYME_INFO=$ENZYME_INFO
  echo ANALYSIS=$ANALYSIS
}

#
# edit this method to set required environment (or set up
# before running this script)
#
function configure_env() {
   export CONDA_ENVS_PATH=$CONDA_ENVS_PATH:/dataset/bioinformatics_dev/active/conda-env

   cd $MELSEQ_PRISM_BIN
   cp ./melseq_prism.sh $OUT_DIR
   cp ./melseq_prism.mk $OUT_DIR
   cp ./add_sample_name.py $OUT_DIR
   cp ./countUniqueReads.sh $OUT_DIR
   cp ./summarizeR_counts.code $OUT_DIR
   cp $GBS_PRISM_BIN/demultiplex_prism.sh $OUT_DIR
   cp $GBS_PRISM_BIN/demultiplex_prism.mk $OUT_DIR
   cp profile_prism.py $OUT_DIR
   cp seq_prisms/data_prism.py $OUT_DIR
   cp seq_prisms/tax_summary_heatmap.r $OUT_DIR

   echo "
export CONDA_ENVS_PATH=$CONDA_ENVS_PATH
conda activate bioconductor
PATH="$OUT_DIR:\$PATH"
PYTHONPATH="$OUT_DIR:\$PYTHONPATH"
" > $OUT_DIR/configure_bioconductor_env.src

   echo "
export CONDA_ENVS_PATH=$CONDA_ENVS_PATH
conda activate bifo-essential
PATH="$OUT_DIR:\$PATH"
" > $OUT_DIR/configure_cutadapt_env.src


   cd $OUT_DIR

}


function check_env() {
   if [ -z "$SEQ_PRISMS_BIN" ]; then
      echo "SEQ_PRISMS_BIN not set - exiting"
      exit 1
   fi
   if [ -z "$MELSEQ_PRISM_BIN" ]; then
      echo "MELSEQ_PRISM_BIN not set - exiting"
      exit 1
   fi
}

function get_targets() {

   rm -f $OUT_DIR/melseq_targets.txt
   rm -f $OUT_DIR/processed_file_targets.txt
   rm -f $OUT_DIR/input_file_list.txt
   touch $OUT_DIR/processed_file_targets.txt

   for ((j=0;$j<$NUM_FILES;j=$j+1)) do
      file=${files_array[$j]}
      echo $file >> $OUT_DIR/input_file_list.txt
      if [ $ANALYSIS == "demultiplex" ]; then 
         file_base=`basename $file`
         moniker=${file_base}

         # for demultiplex, different files are different make targets 
         echo $OUT_DIR/$moniker.$ANALYSIS  >> $OUT_DIR/${ANALYSIS}_targets.txt
         script=$OUT_DIR/${moniker}.${ANALYSIS}.sh
         if [ -f $script ]; then
            if [ ! $FORCE == yes ]; then
               echo "found existing gbs script $script  - will re-use (use -f to force rebuild of scripts) "
               continue
            fi
         fi

         enzyme_info_phrase=""
         if [ ! -z $ENZYME_INFO ]; then
            enzyme_info_phrase="-e $ENZYME_INFO"
         fi

         ############### demultiplex script
         echo "#!/bin/bash
cd $OUT_DIR
mkdir -p demultiplex
# run demultiplexing
time ./demultiplex_prism.sh -C $HPC_TYPE -x gbsx -l $SAMPLE_INFO  $enzyme_info_phrase  -O $OUT_DIR/demultiplex \`cat $OUT_DIR/input_file_list.txt\` 
if [ \$? != 0 ]; then
   echo \"warning demultiplex returned an error code\"
   exit 1
fi
      " > $OUT_DIR/${moniker}.demultiplex.sh
         chmod +x $OUT_DIR/${moniker}.demultiplex.sh
      fi
   done


   # for other processing, all files are part of a single make target 
   for analysis_type in trim format blast summarise kmer_analysis html; do
      echo $OUT_DIR/all.$analysis_type  > $OUT_DIR/${analysis_type}_targets.txt
   done

   ################ trim script
   # trims seqs
   # the trim script will launch a command file that we also prepare here
   # generate command file:
   rm -f $OUT_DIR/trim_commands.txt
   for file in `cat $OUT_DIR/input_file_list.txt`; do
      file_base=`basename $file .fastq.gz`
      file_dir=`dirname $file`
      # dont want any more than one or 2 chunks 
      echo "tardis -q --hpctype $HPC_TYPE  -c 999999999 cutadapt -f fastq -q $seqqual_min  -m $seqlength_min _condition_fastq_input_$file -o _condition_uncompressedfastq_output_$OUT_DIR/trimming/${file_base}_trimmed.fastq > $OUT_DIR/trimming/${file_base}.trimReport 2>&1" >> $OUT_DIR/trim_commands.txt
   done
   # the script that will be launched to launch those 
echo "#!/bin/bash
cd $OUT_DIR
mkdir -p trimming
tardis -c 1 --hpctype $HPC_TYPE -d $OUT_DIR/trimming --shell-include-file $OUT_DIR/configure_cutadapt_env.src source _condition_text_input_$OUT_DIR/trim_commands.txt > $OUT_DIR/trimming.log 2>&1
if [ \$? != 0 ]; then
   echo \"warning trimming returned an error code\"
   exit 1
fi
     " >  $OUT_DIR/all.trim.sh
   chmod +x $OUT_DIR/all.trim.sh

   ################ format script
   # converts to fasta, also adding the sample name into the id line , as in this exmaple : 
   #iramohio-01$ head /bifo/scratch/GBS_Rumen_Metagenomes/toBlastPstI/B74231_CTACAGA_psti.R1_trimmed_allReads.fa

   #>B74231_CTACAGA_psti.000000001 D00390:318:CB6K1ANXX:5:2302:1489:2053
   #TGCAGAACGTGGCACAGAATGGTGACCACATCATTGCTGC
   #>B74231_CTACAGA_psti.000000002 D00390:318:CB6K1ANXX:5:2302:4605:2098
   #TGCAGCAGAAGAAAAAGCGCCTGAAGCAGAGAAAGCTCCTGAGGCAGCAAAACCTGAGCCTGCAAAGGAAGAAGAGTATGTAAATGCTCCGG

   # the format  script will launch two command files that we also prepare here
   # generate format conversion command file:
   rm -f $OUT_DIR/format_commands.txt
   rm -f $OUT_DIR/count_commands.txt
   for file in `cat $OUT_DIR/input_file_list.txt`; do
      file_base=`basename $file .fastq.gz`
      file_dir=`dirname $file`
      # dont want any more than one or 2 chunks 
      echo "tardis -q --hpctype $HPC_TYPE -c 999999999 cat _condition_fastq2fasta_input_$file | $OUT_DIR/add_sample_name.py $file_base > $OUT_DIR/fasta/${file_base}.fasta 2>&1" >> $OUT_DIR/format_commands.txt
      echo "cat $OUT_DIR/fasta/${file_base}.fasta | $OUT_DIR/countUniqueReads.sh  > $OUT_DIR/fasta/${file_base}.non-redundant.fasta 2>&1" >> $OUT_DIR/count_commands.txt
   done
   # the script that will be launched to launch those 
echo "#!/bin/bash
cd $OUT_DIR
mkdir -p fasta
tardis --hpctype $HPC_TYPE  -c 1 -d $OUT_DIR/fasta source _condition_text_input_$OUT_DIR/format_commands.txt > $OUT_DIR/format.log 2>&1
if [ \$? != 0 ]; then
   echo \"warning fasta conversion returned an error code\"
   exit 1
fi
tardis --hpctype $HPC_TYPE -c 1 -d $OUT_DIR/fasta source _condition_text_input_$OUT_DIR/count_commands.txt > $OUT_DIR/count.log 2>&1
if [ \$? != 0 ]; then
   echo \"warning count nonredundant returned an error code\"
   exit 1
fi
     " >  $OUT_DIR/all.format.sh
   chmod +x $OUT_DIR/all.format.sh

   ################ blast script
   # blasts seqs
echo "#!/bin/bash
cd $OUT_DIR
mkdir -p blast
$SEQ_PRISMS_BIN/align_prism.sh -C $HPC_TYPE  -f -a blastn -r $taxonomy_blast_database -p \"-num_threads 4 -outfmt \\'6 std qlen \\' -evalue $similarity\"  -O $OUT_DIR/blast \`cat $OUT_DIR/input_file_list.txt\` > $OUT_DIR/blast.log 2>&1 

if [ \$? != 0 ]; then
   echo \"warning blast returned an error code\"
   exit 1
fi
     " >  $OUT_DIR/all.blast.sh
   chmod +x $OUT_DIR/all.blast.sh

   ################ summarise script
   # summarise results 
   # the summary  script will launch a command file that we also prepare here
   # generate command file:
   rm -f $OUT_DIR/summary_commands.txt
   # generate command file
   for file in `cat $OUT_DIR/input_file_list.txt`; do
      base=`basename $file .results.gz`
      echo "gunzip -c $file  > $OUT_DIR/summary/${base}.resultsNucl ; Rscript --vanilla $OUT_DIR/summarizeR_counts.code $OUT_DIR/summary/${base}.resultsNucl 1>$OUT_DIR/summary/${base}.resultsNucl.stdout 2>$OUT_DIR/summary/${base}.resultsNucl.stderr; /usr/bin/rm -f $OUT_DIR/summary/${base}.resultsNucl" >> $OUT_DIR/summary_commands.txt
   done

   # the script that will be launched to launch those 
echo "#!/bin/bash
cd $OUT_DIR
mkdir -p summary
tardis --hpctype $HPC_TYPE -c 1 -d $OUT_DIR/summary  source _condition_text_input_$OUT_DIR/summary_commands.txt > $OUT_DIR/summary.log 2>&1
if [ \$? != 0 ]; then
   echo \"warning summary returned an error code\"
   exit 1
fi
     " >  $OUT_DIR/all.summarise.sh
   chmod +x $OUT_DIR/all.summarise.sh


   ################ kmer_analysis script
   # summaries kmer distribution
echo "#!/bin/bash
cd $OUT_DIR
mkdir -p kmer_analysis
$SEQ_PRISMS_BIN/kmer_prism.sh -C $HPC_TYPE -a fasta -p \"-k 6 -A --weighting_method tag_count\" -O $OUT_DIR/kmer_analysis \`cat $OUT_DIR/input_file_list.txt\` > $OUT_DIR/kmer_analysis.log 2>&1  

if [ \$? != 0 ]; then
   echo \"warning kmer_analysis returned an error code\"
   exit 1
fi
     " >  $OUT_DIR/all.kmer_analysis.sh
   chmod +x $OUT_DIR/all.kmer_analysis.sh


   ################ html script
   # summaries of the summaries 
echo "#!/bin/bash
cd $OUT_DIR
mkdir -p html 
# summaries at genus and species level for the plots
tardis --hpctype $HPC_TYPE $OUT_DIR/profile_prism.py --weighting_method line \`cat $OUT_DIR/input_file_list.txt\` > $OUT_DIR/html.log 2>&1
tardis --hpctype $HPC_TYPE -q $OUT_DIR/profile_prism.py --summary_type summary_table --measure frequency \`cat $OUT_DIR/input_file_list.txt | awk '{printf(\"%s.taxonomy.pickle\\n\", \$1);}' -\` > $OUT_DIR/html/taxonomy_frequency_table.txt 2>>$OUT_DIR/html.log
tardis --hpctype $HPC_TYPE --shell-include-file $OUT_DIR/configure_bioconductor_env.src Rscript --vanilla $OUT_DIR/tax_summary_heatmap.r num_profiles=60 moniker=taxonomy_frequency_table datafolder=$OUT_DIR/html >> $OUT_DIR/html.log 2>&1 
# 
# now do summaries just at genus level for the tabular output - i.e. just repeat above , but pass in the 
# non-default column(s) you want summarised. (Note that the column numbering is zero based )

tardis --hpctype $HPC_TYPE $OUT_DIR/profile_prism.py --weighting_method line --columns 6 \`cat $OUT_DIR/input_file_list.txt\` >> $OUT_DIR/html.log 2>&1
tardis --hpctype $HPC_TYPE -q $OUT_DIR/profile_prism.py --summary_type summary_table --measure frequency \`cat $OUT_DIR/input_file_list.txt | awk '{printf(\"%s.taxonomy.pickle\\n\", \$1);}' -\` > $OUT_DIR/html/taxonomy_genus_frequency_table.txt 2>>$OUT_DIR/html.log
tardis --hpctype $HPC_TYPE --shell-include-file $OUT_DIR/configure_bioconductor_env.src Rscript --vanilla $OUT_DIR/tax_summary_heatmap.r num_profiles=70 moniker=taxonomy_genus_frequency_table datafolder=$OUT_DIR/html >> $OUT_DIR/html.log 2>&1

if [ \$? != 0 ]; then
   echo \"warning html step returned an error code\"
   exit 1
fi
     " >  $OUT_DIR/all.html.sh
   chmod +x $OUT_DIR/all.html.sh
}


function fake_prism() {
   echo "dry run ! "
   make -n -f melseq_prism.mk -d -k  --no-builtin-rules -j 16 `cat $OUT_DIR/${ANALYSIS}_targets.txt` > $OUT_DIR/${ANALYSIS}.log 2>&1
   echo "dry run : summary commands are 
   "
   exit 0
}

function run_prism() {
   # this prepares each file
   make -f melseq_prism.mk -d -k  --no-builtin-rules -j 16 `cat $OUT_DIR/${ANALYSIS}_targets.txt` > $OUT_DIR/${ANALYSIS}.log 2>&1
}

function clean() {
   rm -rf $OUT_DIR/tardis_*
}

function main() {
   get_opts "$@"
   check_opts
   echo_opts
   check_env
   configure_env
   get_targets
   if [ $DRY_RUN != "no" ]; then
      fake_prism
   else
      run_prism
      if [ $? == 0 ] ; then
         clean
      else
         echo "error state from melseq run - skipping clean "
         exit 1
      fi
   fi
}


set -x
main "$@"
set +x

