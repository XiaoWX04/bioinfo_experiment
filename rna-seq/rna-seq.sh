#!bin/bash

# 定义一个空列表来存放样本文件前缀
prefix_list=()


# 遍历文件夹里的所有文件
for file in samples/*; do
    # 提取文件名中的前缀部分
    file_basename=$(basename "$file")
    prefix="${file_basename%_chrX_1.fastq.gz}"
    prefix="${prefix%_chrX_2.fastq.gz}"
    # 将前缀添加到列表中，确保不重复
    if [[ ! " ${prefix_list[@]} " =~ " ${prefix} " ]]; then
        prefix_list+=("$prefix")
    fi
done

echo "prefix in samples are:"
for prefix in "${prefix_list[@]}"; do
    echo "$prefix"
done

source /gpfs1/home/bjx034_pkuhpc/miniconda3/bin/activate /gpfs1/home/bjx034_pkuhpc/miniconda3/envs/rna-seq

# 先进行rna-seq环境里的任务
for prefix in "${prefix_list[@]}"; do
    #	cutadapt去接头
    echo "----------cutadapt for sample $prefix...----------"
    cutadapt -a AGATCGGAAGAGCACACGTCTGAACTCCAGTCAC -A AGATCGGAAGAGCGTCGTGTAGGGAAAGAGTGT -m 30 -j 10 -o samples/${prefix}_chrX_cleaned_1.fastq.gz -p samples/${prefix}_chrX_cleaned_2.fastq.gz samples/${prefix}_chrX_1.fastq.gz samples/${prefix}_chrX_2.fastq.gz
    cutadapt -a "A{10}" -j 10 -o samples/${prefix}_chrX_cleaned2_1.fastq.gz -p samples/${prefix}_chrX_cleaned2_2.fastq.gz samples/${prefix}_chrX_cleaned_1.fastq.gz samples/${prefix}_chrX_cleaned_2.fastq.gz
done

#bowtie2构建索引
mkdir "index"
cd index
echo "----------bowtie2 building...----------"
bowtie2-build ../class5/ref/chrX.fa chrX
cd ..

conda deactivate
source /gpfs1/home/bjx034_pkuhpc/miniconda3/bin/activate /gpfs1/home/bjx034_pkuhpc/miniconda3/envs/tophat2


cp chrX.fa index/
#进行tophat2环境里的任务
for prefix in "${prefix_list[@]}"; do
        mkdir "$prefix"
        cd "$prefix"
        mkdir "align"
  echo "----------mapping ${prefix}...----------"
        tophat2 -p 10 -G ../class5/chrX_data/genes/chrX.gtf -o align ../index/chrX ../samples/${prefix}_chrX_cleaned2_1.fastq.gz ../samples/${prefix}_chrX_cleaned2_2.fastq.gz 
        mkdir "cufflinks"
	echo "----------cufflinks for sample $prefix...----------"
        cufflinks -o cufflinks/ -p 10 align/accepted_hits.bam
        echo "${prefix}/cufflinks/transcripts.gtf" >> ../assembly_list.txt
        mkdir "cuffquant"
        cd cuffquant
	echo "----------cuffquant for sample $prefix...----------"
        cuffquant -p 10 -u ../../class5/chrX_data/genes/chrX.gtf ../align/accepted_hits.bam
        cd ../
        cd ../
done

#cuffmerge整合转录本
mkdir "cuffmerge"
echo "----------cuffmerging...----------"
cuffmerge -p 10 -g class5/chrX_data/genes/chrX.gtf -o cuffmerge/ assembly_list.txt
mkdir "cuffdiff"
cd cuffdiff
echo "----------cuffdiffing...----------"
#samples=$(IFS=','; echo "${prefix_list[*]}")
 cuffdiff -b ../chrX.fa ../cuffmerge/merged.gtf -u -L ERR188044,ERR188104,ERR188234,ERR188245,ERR188257,ERR188337,ERR188383,ERR188401,ERR188428,ERR188454,ERR209416 ../ERR188044/align/accepted_hits.bam  ../ERR188104/align/accepted_hits.bam ../ERR188234/align/accepted_hits.bam  ../ERR188245/align/accepted_hits.bam  ../ERR188257/align/accepted_hits.bam  ../ERR188337/align/accepted_hits.bam ../ERR188383/align/accepted_hits.bam  ../ERR188401/align/accepted_hits.bam ../ERR188428/align/accepted_hits.bam ../ERR188454/align/accepted_hits.bam ../ERR204916/align/accepted_hits.bam -p 15 -o ./
#这里我实在是不知道怎么把BAM文件列表作为参数传入，只好手敲了，如果能完善这个地方这个脚本会实用很多


