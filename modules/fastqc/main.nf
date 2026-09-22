process FASTQC {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*.html"), emit: html
    tuple val(meta), path("*.zip"), emit: zip
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    fastqc \\
        ${args} \\
        --threads ${task.cpus} \\
        ${reads}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastqc: \$( fastqc --version | sed -n "s/^FastQC v//p" )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}_fastqc.html
    touch ${prefix}_fastqc.zip

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastqc: stub
    END_VERSIONS
    """
}
