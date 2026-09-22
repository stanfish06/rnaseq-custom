process RUSTQC_RNA {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(bam), path(bai)
    path gtf

    output:
    tuple val(meta), path("*", type: 'dir'), emit: results
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def paired = meta.single_end ? '' : '--paired'
    """
    rustqc rna \\
        ${bam} \\
        --gtf ${gtf} \\
        --outdir ${prefix} \\
        --sample-name ${prefix} \\
        --threads ${task.cpus} \\
        ${paired} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rustqc: \$( rustqc --version | awk 'NR == 1 { print \$2 }' )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    mkdir -p ${prefix}
    touch ${prefix}/CITATIONS.md

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        rustqc: stub
    END_VERSIONS
    """
}
