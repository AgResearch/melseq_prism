#!/bin/bash

#
# steps to build initial GTDB based database
#

BUILD_DIR=/dataset/gseq_processing/scratch/melseq/gtdb
function get_data() {
   comment="
in /dataset/gseq_processing/scratch/melseq/gtdb 

iramohio-01$ wget https://data.gtdb.ecogenomic.org/releases/release207/207.0/genomic_files_reps/gtdb_genomes_reps_r207.tar.gz
--2022-10-31 13:20:12-- https://data.gtdb.ecogenomic.org/releases/release207/207.0/genomic_files_reps/gtdb_genomes_reps_r207.tar.gz
Resolving webgate.agresearch.co.nz (webgate.agresearch.co.nz)... 10.21.101.20
Connecting to webgate.agresearch.co.nz (webgate.agresearch.co.nz)|10.21.101.20|:8080... connected.
Proxy request sent, awaiting response... 200 OK
Length: 65396676602 (61G) [application/octet-stream]
Saving to: ‘gtdb_genomes_reps_r207.tar.gz’


2022-10-31 13:48:49 (36.4 MB/s) - ‘gtdb_genomes_reps_r207.tar.gz’ saved [65396676602/65396676602]

iramohio-01$
iramohio-01$ wget https://data.gtdb.ecogenomic.org/releases/release207/207.0/bac120_taxonomy_r207.tsv.gz
--2022-10-31 16:31:12-- https://data.gtdb.ecogenomic.org/releases/release207/207.0/bac120_taxonomy_r207.tsv.gz
Resolving webgate.agresearch.co.nz (webgate.agresearch.co.nz)... 10.21.101.20
Connecting to webgate.agresearch.co.nz (webgate.agresearch.co.nz)|10.21.101.20|:8080... connected.
Proxy request sent, awaiting response... 200 OK
Length: 3226423 (3.1M) [application/octet-stream]
Saving to: ‘bac120_taxonomy_r207.tsv.gz’

100%[=====================================================================================================================================================================>] 3,226,423 9.00MB/s in 0.3s

2022-10-31 16:31:13 (9.00 MB/s) - ‘bac120_taxonomy_r207.tsv.gz’ saved [3226423/3226423]

iramohio-01$ wget https://data.gtdb.ecogenomic.org/releases/release207/207.0/ar53_taxonomy_r207.tsv.gz
--2022-11-07 12:05:05--  https://data.gtdb.ecogenomic.org/releases/release207/207.0/ar53_taxonomy_r207.tsv.gz
Resolving webgate.agresearch.co.nz (webgate.agresearch.co.nz)... 10.21.101.20
Connecting to webgate.agresearch.co.nz (webgate.agresearch.co.nz)|10.21.101.20|:8080... connected.
Proxy request sent, awaiting response... 200 OK
Length: 92148 (90K) [application/octet-stream]
Saving to: ‘ar53_taxonomy_r207.tsv.gz’

100%[===================================================================================================================================================>] 92,148      --.-K/s   in 0.07s

2022-11-07 12:05:06 (1.26 MB/s) - ‘ar53_taxonomy_r207.tsv.gz’ saved [92148/92148]




gunzip -c gtdb_genomes_reps_r207.tar.gz | tar -xvf -
nohup find gtdb_genomes_reps_r207/GCA -name ".fna.gz" -exec gunzip -c {} ; >> GCA.fna &
nohup find gtdb_genomes_reps_r207/GCF -name ".fna.gz" -exec gunzip -c {} ; >> GCF.fna &
"

}

function collate_fasta() {
   rm $BUILD_DIR/GCA.fna
   rm $BUILD_DIR/GCF.fna
   nohup find $BUILD_DIR/gtdb_genomes_reps_r207/GCA -name "*.fna.gz" -exec pypy format_database.py -t format_fasta {} \; >> $BUILD_DIR/GCA.fna &
   nohup find $BUILD_DIR/gtdb_genomes_reps_r207/GCF -name "*.fna.gz" -exec pypy format_database.py -t format_fasta {} \; >> $BUILD_DIR/GCF.fna &
   cd 

}

function make_blast_db() {
   # conda activate /dataset/bioinformatics_dev/active/conda-env/blast2.9 before running this
   cd $BUILD_DIR
   nohup makeblastdb -in GCA.fna -dbtype nucl & 
   nohup makeblastdb -in GCF.fna -dbtype nucl &
}

function format_taxonomy() {
    ./format_database.py -t format_taxonomy bac120_taxonomy_r207.tsv.gz ar53_taxonomy_r207.tsv.gz > $BUILD_DIR/GTDB1_taxonomy.csv
}

function test_summary() {
   mkdir -p /dataset/sequencing_facility_replication/scratch/microbiome_fasta/qc/SQ1917_HGT5JDRX2_s_1_fastq.txt.gz/summary
   #gunzip -c /bifo/scratch/sequencing_facility_replication/microbiome_fasta/qc/SQ1917_HGT5JDRX2_s_1_fastq.txt.gz/blast/SQ1917_HGT5JDRX2_s_merged_fastq.txt.gz.demultiplexed_966045_CAACTGACTG_psti.R1_trimmed.fastq.non-redundant.fasta.blastn.GTDB1.num_threads4taskblastnword_size16outfmt6stdqlenevalue0.02.results.gz  > /dataset/sequencing_facility_replication/scratch/microbiome_fasta/qc/SQ1917_HGT5JDRX2_s_1_fastq.txt.gz/summary/SQ1917_HGT5JDRX2_s_merged_fastq.txt.gz.demultiplexed_966045_CAACTGACTG_psti.R1_trimmed.fastq.non-redundant.fasta.blastn.GTDB1.num_threads4taskblastnword_size16outfmt6stdqlenevalue0.02.resultsNucl  
   Rscript --vanilla /dataset/sequencing_facility_replication/scratch/microbiome_fasta/qc/SQ1917_HGT5JDRX2_s_1_fastq.txt.gz/summarizeR_counts.code /dataset/sequencing_facility_replication/scratch/microbiome_fasta/qc/SQ1917_HGT5JDRX2_s_1_fastq.txt.gz/summary/SQ1917_HGT5JDRX2_s_merged_fastq.txt.gz.demultiplexed_966045_CAACTGACTG_psti.R1_trimmed.fastq.non-redundant.fasta.blastn.GTDB1.num_threads4taskblastnword_size16outfmt6stdqlenevalue0.02.resultsNucl 1>/dataset/sequencing_facility_replication/scratch/microbiome_fasta/qc/SQ1917_HGT5JDRX2_s_1_fastq.txt.gz/summary/SQ1917_HGT5JDRX2_s_merged_fastq.txt.gz.demultiplexed_966045_CAACTGACTG_psti.R1_trimmed.fastq.non-redundant.fasta.blastn.GTDB1.num_threads4taskblastnword_size16outfmt6stdqlenevalue0.02.resultsNucl.stdout 2>/dataset/sequencing_facility_replication/scratch/microbiome_fasta/qc/SQ1917_HGT5JDRX2_s_1_fastq.txt.gz/summary/SQ1917_HGT5JDRX2_s_merged_fastq.txt.gz.demultiplexed_966045_CAACTGACTG_psti.R1_trimmed.fastq.non-redundant.fasta.blastn.GTDB1.num_threads4taskblastnword_size16outfmt6stdqlenevalue0.02.resultsNucl.stderr
  #/usr/bin/rm -f /dataset/sequencing_facility_replication/scratch/microbiome_fasta/qc/SQ1917_HGT5JDRX2_s_1_fastq.txt.gz/summary/SQ1917_HGT5JDRX2_s_merged_fastq.txt.gz.demultiplexed_966045_CAACTGACTG_psti.R1_trimmed.fastq.non-redundant.fasta.blastn.GTDB1.num_threads4taskblastnword_size16outfmt6stdqlenevalue0.02.resultsNucl
}

#collate_fasta
#make_blast_db
#format_taxonomy 
test_summary
