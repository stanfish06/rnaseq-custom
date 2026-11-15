process SEQKIT_STATS {
    tag "${meta.id}"
    label 'process_dual'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.seqkit_stats.tsv"), emit: stats
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    seqkit stats \\
        --all \\
        --tabular \\
        --threads ${task.cpus} \\
        ${args} \\
        ${reads} \\
        > ${prefix}.seqkit_stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: \$( seqkit version | sed -e "s/seqkit v//g" )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.seqkit_stats.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        seqkit: stub
    END_VERSIONS
    """
}
