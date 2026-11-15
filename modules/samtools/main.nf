process SAMTOOLS_INDEX {
    tag "${meta.id}"
    label 'process_dual'

    input:
    tuple val(meta), path(bam)

    output:
    tuple val(meta), path(bam), path("*.bai"), emit: bam_bai
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    samtools index -@ ${task.cpus} ${args} ${bam}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$( samtools --version | sed -n "1s/samtools //p" )
    END_VERSIONS
    """

    stub:
    """
    touch ${bam}.bai

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub
    END_VERSIONS
    """
}

process SAMTOOLS_FLAGSTAT {
    tag "${meta.id}"
    label 'process_mono'

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*.flagstat"), emit: flagstat
    path "versions.yml", emit: versions

    script:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    samtools flagstat -@ ${task.cpus} ${bam} > ${prefix}.flagstat

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: \$( samtools --version | sed -n "1s/samtools //p" )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.flagstat

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        samtools: stub
    END_VERSIONS
    """
}
