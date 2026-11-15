process STAR_GENOMEGENERATE {
    tag "${meta.id}"
    label 'process_octa'
    maxForks 1

    input:
    tuple val(meta), path(fasta), path(gtf)

    output:
    tuple val(meta), path("star"), emit: index
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p star
    STAR \\
        --runMode genomeGenerate \\
        --runThreadN ${task.cpus} \\
        --genomeDir star \\
        --genomeFastaFiles ${fasta} \\
        --sjdbGTFfile ${gtf} \\
        --limitGenomeGenerateRAM ${task.memory.toBytes()} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: \$( STAR --version | sed -e "s/STAR_//g" )
    END_VERSIONS
    """

    stub:
    """
    mkdir -p star
    touch star/SA

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: stub
    END_VERSIONS
    """
}

process STAR_ALIGN {
    tag "${meta.id}"
    label 'process_octa'

    input:
    tuple val(meta), path(reads), path(index), path(gtf)

    output:
    tuple val(meta), path("*.sorted.bam"), emit: bam
    tuple val(meta), path("*.toTranscriptome.out.bam"), emit: transcriptome_bam, optional: true
    tuple val(meta), path("*.Log.final.out"), emit: log_final
    tuple val(meta), path("*.ReadsPerGene.out.tab"), emit: gene_counts, optional: true
    tuple val(meta), path("*.SJ.out.tab"), emit: junctions
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def read_cmd = reads[0].name.endsWith('.gz') ? '--readFilesCommand zcat' : ''
    def sort_ram = (task.memory.toBytes() * 0.5).longValue()
    """
    STAR \\
        --runThreadN ${task.cpus} \\
        --genomeDir ${index} \\
        --sjdbGTFfile ${gtf} \\
        --readFilesIn ${reads} \\
        ${read_cmd} \\
        --outFileNamePrefix ${prefix}. \\
        --outSAMtype BAM SortedByCoordinate \\
        --outSAMattrRGline ID:${prefix} SM:${prefix} \\
        --limitBAMsortRAM ${sort_ram} \\
        ${args}

    mv ${prefix}.Aligned.sortedByCoord.out.bam ${prefix}.sorted.bam
    if [ -f ${prefix}.Aligned.toTranscriptome.out.bam ]; then
        mv ${prefix}.Aligned.toTranscriptome.out.bam ${prefix}.toTranscriptome.out.bam
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: \$( STAR --version | sed -e "s/STAR_//g" )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.sorted.bam
    touch ${prefix}.toTranscriptome.out.bam
    touch ${prefix}.Log.final.out
    touch ${prefix}.ReadsPerGene.out.tab
    touch ${prefix}.SJ.out.tab

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        star: stub
    END_VERSIONS
    """
}
