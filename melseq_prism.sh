#!/bin/bash

declare -a files_array

NUM_THREADS=8 #for make

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
   taxonomiser=$MELSEQ_PRISM_BIN/summarizeR_counts.code
   seqlength_min=40
   seqqual_min=20
   similarity=0.02
   wordsize=16
   blast_task=blastn
   adapter_to_trim=""
   blast_extra=""
   help_text="
\n
./melseq_prism.sh  [-h] [-n] [-d] -a analysis -b blast_database [-w wordsize (16)] [-T blastn|megablast (blastn)] -s similarity (.02)] [-m min_length (40)] [-q min_qual (20)]  [-C local|slurm (slurm)] -O outdir input_file_names\n
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
   while getopts ":nhdfO:C:b:t:m:s:q:a:l:e:A:w:T:t:x:" opt; do
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
       O)
         OUT_DIR=$OPTARG
         ;;
       C)
         HPC_TYPE=$OPTARG
         ;;
       e)
         ENZYME_INFO=$OPTARG
         ;;
       a)
         ANALYSIS=$OPTARG
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
       w)
         wordsize=$OPTARG
         ;;
       T)
         blast_task=$OPTARG
         ;;
       t)
         taxonomiser=$OPTARG
         ;;
       A)
         adapter_to_trim=$OPTARG
         ;;
       b)
         taxonomy_blast_database=$OPTARG
         ;;
       s)
         similarity=$OPTARG
         ;;
       x)
         blast_extra=$OPTARG
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
   if [[ ( $ANALYSIS != "demultiplex" ) && ( $ANALYSIS != "trim" ) && ( $ANALYSIS != "format" ) && ( $ANALYSIS != "merge_lanes" ) && ( $ANALYSIS != "blast" ) && ( $ANALYSIS != "kmer_analysis" ) && ( $ANALYSIS != "summarise" )  && ( $ANALYSIS != "html" ) ]] ; then
      echo "analysis must be one of demultiplex, trim , format, merge_lanes, blast, summarise , html, clean) "
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
   if [[ $blast_task != "blastn" && $blast_task != "megablast" ]]; then
      echo "HPC_TYPE must be one of local, slurm"
      exit 1
   fi
   if [ ! -z $taxonomy_blast_database ]; then
      if [[ ( ! -f ${taxonomy_blast_database}.nin ) && ( ! -f ${taxonomy_blast_database}.nal ) ]]; then
         echo "bad blast database (cant see ${taxonomy_blast_database}.nin or ${taxonomy_blast_database}.nal ) (you might need to supply the full path ?)"
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
   python -c "print float('$wordsize')" >/dev/null 2>&1
   if [ $? != 0 ]; then
      echo "looks like wordsize requested ( $wordsize ) is not a number"
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
  
   if [ ! -f $taxonomiser ]; then
      echo "Error taxonomiser $taxonomiser does not exist"
      exit 1
   fi

}

function echo_opts() {
  echo OUT_DIR=$OUT_DIR
  echo DRY_RUN=$DRY_RUN
  echo DEBUG=$DEBUG
  echo HPC_TYPE=$HPC_TYPE
  echo taxonomy_blast_database=$taxonomy_blast_database
  echo taxonomiser=$taxonomiser
  echo blast_extra=$blast_extra
  echo similarity=$similarity
  echo seqqal_min=$seqqal_min
  echo seqlength_min=$seqlength_min
  echo wordsize=$wordsize
  echo blast_task=$blast_task
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
   cp $taxonomiser $OUT_DIR
   cp $GBS_PRISM_BIN/demultiplex_prism.sh $OUT_DIR
   cp $GBS_PRISM_BIN/demultiplex_prism.mk $OUT_DIR
   cp profile_prism.py $OUT_DIR
   cp merge_lanes.py $OUT_DIR
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
conda activate $MELSEQ_PRISM_BIN/conda/cutadapt
PATH="$OUT_DIR:\$PATH"
" > $OUT_DIR/configure_cutadapt_env.src

echo "conda activate /dataset/gseq_processing/active/bin/melseq_prism/conda/cutadapt" > env.inc

  echo "
export TMP=$OUT_DIR/TEMP
export TEMP=$OUT_DIR/TEMP
export TMPDIR=$OUT_DIR/TEMP
" > $OUT_DIR/configure_temp_env.src

   echo "
conda activate /dataset/bioinformatics_dev/active/conda-env/blast2.9
" > $OUT_DIR/blast_env.inc


   echo "
max_tasks = 80
jobtemplatefile = \"$MELSEQ_PRISM_BIN/etc/melseq_slurm_array_job\"
" > $OUT_DIR/tardis.toml

   cd $OUT_DIR
   mkdir TEMP

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
   done


   # for all processing, all files are part of a single make target 
   for analysis_type in demultiplex trim format merge_lanes blast summarise kmer_analysis html; do
      echo $OUT_DIR/all.$analysis_type  > $OUT_DIR/${analysis_type}_targets.txt
   done

   ################ demultiplex script 
   enzyme_info_phrase=""
   if [ ! -z $ENZYME_INFO ]; then
      enzyme_info_phrase="-e $ENZYME_INFO"
   fi

   echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
export MELSEQ_PRISM_BIN=$MELSEQ_PRISM_BIN

cd $OUT_DIR
mkdir -p demultiplex
# run demultiplexing
time ./demultiplex_prism.sh -C $HPC_TYPE -x gbsx -l $SAMPLE_INFO  $enzyme_info_phrase  -O $OUT_DIR/demultiplex \`cat $OUT_DIR/input_file_list.txt\`
if [ \$? != 0 ]; then
   echo \"warning demultiplex returned an error code\"
   exit 1
fi
   " > $OUT_DIR/all.demultiplex.sh
   chmod +x $OUT_DIR/all.demultiplex.sh


   ################ trim script
   # The merge_lanes.py script generates a command file which both merges (novaseq) lanes, and also trims. It generates command file:
   adapter_phrase=""
   if [ ! -z "$adapter_to_trim" ]; then
      adapter_phrase="-a $adapter_to_trim "
   fi
   python merge_lanes.py -t generate_merge_trim_commands -a "$adapter_phrase" -M $OUT_DIR/trimming -O $OUT_DIR/trim_commands.txt  $OUT_DIR/input_file_list.txt

   # the script that will be launched to launch those 
echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
export MELSEQ_PRISM_BIN=$MELSEQ_PRISM_BIN 

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
   touch $OUT_DIR/format_commands.txt
   touch $OUT_DIR/count_commands.txt
   for file in `cat $OUT_DIR/input_file_list.txt`; do
      file_base=`basename $file .fastq.gz`
      if [ ! -f $OUT_DIR/fasta/${file_base}.non-redundant.fasta ]; then
         # dont want any more than one or 2 chunks 
         echo "tardis -d $OUT_DIR/fasta --hpctype $HPC_TYPE -c 999999999 cat _condition_fastq2fasta_input_$file \| $OUT_DIR/add_sample_name.py $file_base \> $OUT_DIR/fasta/${file_base}.fasta 2\>$OUT_DIR/fasta/${file_base}.fasta.stderr " >> $OUT_DIR/format_commands.txt
         echo "tardis -d $OUT_DIR/fasta --hpctype $HPC_TYPE -c 999999999 cat $OUT_DIR/fasta/${file_base}.fasta \| $OUT_DIR/countUniqueReads.sh $OUT_DIR/TEMP  \> $OUT_DIR/fasta/${file_base}.non-redundant.fasta 2\>$OUT_DIR/fasta/${file_base}.non-redundant.fasta.stderr " >> $OUT_DIR/count_commands.txt
      fi
   done
   # the script that will be launched to launch those 
echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
export MELSEQ_PRISM_BIN=$MELSEQ_PRISM_BIN

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

   ################ merge_lanes script
   # ***********************************************************************
   # ******************* This target and script now deprecated *************
   # ***********************************************************************
   # merges fasta files from different lanes  - motivated by novaseq data which arrives split into lanes
   # e.g. 
   # iramohio-01$ grep 966045_AGGCTAGGAT /dataset/GBS_Microbiomes_Processing/itmp/melseq/SQ1635/blast_input_file_list.txt
   # /dataset/GBS_Microbiomes_Processing/itmp/melseq/SQ1635/fasta/SQ1635_HCH3GDRXY_s_1_fastq.txt.gz.demultiplexed_966045_AGGCTAGGAT_psti.R1_trimmed.fastq.non-redundant.fasta
   # /dataset/GBS_Microbiomes_Processing/itmp/melseq/SQ1635/fasta/SQ1635_HCH3GDRXY_s_2_fastq.txt.gz.demultiplexed_966045_AGGCTAGGAT_psti.R1_trimmed.fastq.non-redundant.fasta

   # the merge script will launch a command files we prepare here
   # generate merge command file:
   rm -f $OUT_DIR/merge_lanes_commands.txt
   $OUT_DIR/merge_lanes.py -M $OUT_DIR/merged_fasta -O $OUT_DIR/merge_lanes_commands.txt  $OUT_DIR/input_file_list.txt >  $OUT_DIR/merge_lanes.py.log 2>&1 
   # the script that will be launched to launch those
echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
export MELSEQ_PRISM_BIN=$MELSEQ_PRISM_BIN

cd $OUT_DIR
mkdir -p merged_fasta
tardis --hpctype $HPC_TYPE  -c 1 -d $OUT_DIR/merged_fasta source _condition_text_input_$OUT_DIR/merge_lanes_commands.txt  > $OUT_DIR/merge_lanes_commands.log 2>&1
if [ \$? != 0 ]; then
   echo \"warning fasta merge returned an error code\"
   exit 1
fi
     " >  $OUT_DIR/all.merge_lanes.sh
   chmod +x $OUT_DIR/all.merge_lanes.sh


   ################ blast script
   # blasts seqs
   if [ $HPC_TYPE == "local" ]; then
      NUM_THREADS=2
   fi
echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
export MELSEQ_PRISM_BIN=$MELSEQ_PRISM_BIN

cd $OUT_DIR
mkdir -p blast
cp $OUT_DIR/tardis.toml blast
rm -f $OUT_DIR/blast/*.fasta # remove any existing shortcuts set up by align_prism (e.g. if restarting)  
$SEQ_PRISMS_BIN/align_prism.sh -C $HPC_TYPE -j 8 -B 4 -m 80 -f -a blastn -e $OUT_DIR/blast_env.inc -r $taxonomy_blast_database -p \"-num_threads 8 -task $blast_task -word_size $wordsize -outfmt \\'6 std qlen \\' -evalue $similarity $blast_extra \"  -O $OUT_DIR/blast \`cat $OUT_DIR/input_file_list.txt\` > $OUT_DIR/blast.log 2>&1 

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
   taxonomiser_base=`basename $taxonomiser`
   rm -f $OUT_DIR/summary_commands.txt
   touch $OUT_DIR/summary_commands.txt
   # generate command file
   for file in `cat $OUT_DIR/input_file_list.txt`; do
      base=`basename $file .results.gz`
      echo "gunzip -c $file  > $OUT_DIR/summary/${base}.resultsNucl ; Rscript --vanilla $OUT_DIR/$taxonomiser_base $OUT_DIR/summary/${base}.resultsNucl 1>$OUT_DIR/summary/${base}.resultsNucl.stdout 2>$OUT_DIR/summary/${base}.resultsNucl.stderr; /usr/bin/rm -f $OUT_DIR/summary/${base}.resultsNucl" >> $OUT_DIR/summary_commands.txt
   done

   # the script that will be launched to launch those 
echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
export MELSEQ_PRISM_BIN=$MELSEQ_PRISM_BIN

cd $OUT_DIR
mkdir -p summary
tardis --hpctype $HPC_TYPE -c 1 -d $OUT_DIR/summary  --shell-include-file $OUT_DIR/configure_temp_env.src source _condition_text_input_$OUT_DIR/summary_commands.txt > $OUT_DIR/summary.log 2>&1
if [ \$? != 0 ]; then
   echo \"warning summary returned an error code\"
   exit 1
fi
     " >  $OUT_DIR/all.summarise.sh
   chmod +x $OUT_DIR/all.summarise.sh


   ################ kmer_analysis script
   # summaries kmer distribution
echo "#!/bin/bash
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
export MELSEQ_PRISM_BIN=$MELSEQ_PRISM_BIN

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
export SEQ_PRISMS_BIN=$SEQ_PRISMS_BIN
export MELSEQ_PRISM_BIN=$MELSEQ_PRISM_BIN

cd $OUT_DIR
mkdir -p html 
# summaries at genus and species level for the plots
tardis --hpctype $HPC_TYPE $OUT_DIR/profile_prism.py --weighting_method line --columns 1,2,3,4,5,6,7 \`cat $OUT_DIR/input_file_list.txt\` \> $OUT_DIR/html.log 2\>$OUT_DIR/html.log
tardis --hpctype $HPC_TYPE $OUT_DIR/profile_prism.py --summary_type summary_table --measure frequency \`cat $OUT_DIR/input_file_list.txt | awk '{printf(\"%s.taxonomy.pickle\\n\", \$1);}' -\` \> $OUT_DIR/html/taxonomy_frequency_table.txt 2\>\>$OUT_DIR/html.log

# make a version with readable headings
# e.g. SQ1917_HGT5JDRX2_s_merged_fastq.txt.gz.demultiplexed_966045_CAACTGACTG_psti.R1_trimmed.fastq.non-redundant.fasta.blastn.GTDB1.num_threads4taskblastnword_size16outfmt6stdqlen
#evalue0.02.summary.taxonomy.pickle to 966045_CAACTGACTG_psti
cat $OUT_DIR/html/taxonomy_frequency_table.txt | python $MELSEQ_PRISM_BIN/edit_summary_column_headings.py > $OUT_DIR/html/taxonomy_frequency_table_plot.txt
#plot
tardis --hpctype $HPC_TYPE --shell-include-file $OUT_DIR/configure_bioconductor_env.src Rscript --vanilla $OUT_DIR/tax_summary_heatmap.r num_profiles=60 moniker=taxonomy_frequency_table_plot datafolder=$OUT_DIR/html \>\> $OUT_DIR/html.log 2\>$OUT_DIR/html.log  
# 
# now do summaries just at genus level for the tabular output - i.e. just repeat above , but pass in the 
# non-default column(s) you want summarised. (Note that the column numbering is zero based )

tardis --hpctype $HPC_TYPE $OUT_DIR/profile_prism.py --weighting_method line --columns 1,2,3,4,5,6  \`cat $OUT_DIR/input_file_list.txt\` \>\> $OUT_DIR/html.log 2\>$OUT_DIR/html.log
tardis --hpctype $HPC_TYPE $OUT_DIR/profile_prism.py --summary_type summary_table --measure frequency \`cat $OUT_DIR/input_file_list.txt | awk '{printf(\"%s.taxonomy.pickle\\n\", \$1);}' -\` \> $OUT_DIR/html/taxonomy_genus_frequency_table.txt 2\>\>$OUT_DIR/html.log

# make a version with readable headings
# e.g. SQ1917_HGT5JDRX2_s_merged_fastq.txt.gz.demultiplexed_966045_CAACTGACTG_psti.R1_trimmed.fastq.non-redundant.fasta.blastn.GTDB1.num_threads4taskblastnword_size16outfmt6stdqlen
#evalue0.02.summary.taxonomy.pickle to 966045_CAACTGACTG_psti
cat $OUT_DIR/html/taxonomy_genus_frequency_table.txt | python $MELSEQ_PRISM_BIN/edit_summary_column_headings.py > $OUT_DIR/html/taxonomy_genus_frequency_table_plot.txt
#plot
tardis --hpctype $HPC_TYPE --shell-include-file $OUT_DIR/configure_bioconductor_env.src Rscript --vanilla $OUT_DIR/tax_summary_heatmap.r num_profiles=70 moniker=taxonomy_genus_frequency_table_plot datafolder=$OUT_DIR/html \>\> $OUT_DIR/html.log 2\>$OUT_DIR/html.log 

if [ \$? != 0 ]; then
   echo \"warning html step returned an error code\"
   exit 1
fi
     " >  $OUT_DIR/all.html.sh
   chmod +x $OUT_DIR/all.html.sh
}


function fake_prism() {
   if [ $HPC_TYPE == "local" ]; then
      NUM_THREADS=2
   fi
   echo "dry run ! "
   make -n -f melseq_prism.mk -d -k  --no-builtin-rules -j $NUM_THREADS `cat $OUT_DIR/${ANALYSIS}_targets.txt` > $OUT_DIR/${ANALYSIS}.log 2>&1
   echo "dry run : summary commands are 
   "
   exit 0
}

function run_prism() {
   # this prepares each file
   if [ $HPC_TYPE == "local" ]; then
      NUM_THREADS=2
   fi
   make -f melseq_prism.mk -d -k  --no-builtin-rules -j $NUM_THREADS `cat $OUT_DIR/${ANALYSIS}_targets.txt` > $OUT_DIR/${ANALYSIS}.log 2>&1
   echo "* done *"
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

