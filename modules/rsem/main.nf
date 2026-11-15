process RSEM_PREPAREREFERENCE {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(fasta), path(gtf)

    output:
    tuple val(meta), path("rsem"), path("rsem/genome.transcripts.fa"), emit: index
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p rsem
    rsem-prepare-reference \\
        --gtf ${gtf} \\
        --num-threads ${task.cpus} \\
        ${args} \\
        ${fasta} \\
        rsem/genome

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rsem: \$( rsem-calculate-expression --version | sed -e "s/Current version: RSEM v//g" )
    END_VERSIONS
    """

    stub:
    """
    mkdir -p rsem
    touch rsem/genome.grp rsem/genome.transcripts.fa

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rsem: stub
    END_VERSIONS
    """
}

process RSEM_CALCULATEEXPRESSION {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(bam), path(index)

    output:
    tuple val(meta), path("*.genes.results"), emit: genes
    tuple val(meta), path("*.isoforms.results"), emit: isoforms
    tuple val(meta), path("*.stat"), emit: stat
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def paired = meta.single_end ? '' : '--paired-end'
    def strand = [unstranded: 'none', forward: 'forward', reverse: 'reverse'][meta.strandedness] ?: 'none'
    """
    rsem-calculate-expression \\
        --alignments \\
        --no-bam-output \\
        --num-threads ${task.cpus} \\
        --strandedness ${strand} \\
        ${paired} \\
        ${args} \\
        ${bam} \\
        ${index}/genome \\
        ${prefix}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rsem: \$( rsem-calculate-expression --version | sed -e "s/Current version: RSEM v//g" )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.genes.results ${prefix}.isoforms.results
    mkdir -p ${prefix}.stat

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rsem: stub
    END_VERSIONS
    """
}
