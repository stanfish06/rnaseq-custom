process SALMON_QUANT {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(bam), path(transcript_fasta), path(gtf)

    output:
    tuple val(meta), path("${meta.id}"), emit: results
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    salmon quant \\
        --libType A \\
        --targets ${transcript_fasta} \\
        --alignments ${bam} \\
        --geneMap ${gtf} \\
        --threads ${task.cpus} \\
        --output ${meta.id} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        salmon: \$( salmon --version | sed -e "s/salmon //g" )
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}
    touch ${meta.id}/quant.sf ${meta.id}/quant.genes.sf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        salmon: stub
    END_VERSIONS
    """
}
