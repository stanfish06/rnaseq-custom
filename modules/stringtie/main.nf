def stringtieStrand(meta) {
    return [forward: '--fr', reverse: '--rf'][meta.strandedness] ?: ''
}

process STRINGTIE_ASSEMBLE {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(bam), path(bai), path(gtf)

    output:
    tuple val(meta), path("*.stringtie.gtf"), emit: gtf
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    stringtie \\
        ${bam} \\
        -G ${gtf} \\
        -o ${prefix}.stringtie.gtf \\
        -p ${task.cpus} \\
        ${stringtieStrand(meta)} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stringtie: \$( stringtie --version )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.stringtie.gtf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stringtie: stub
    END_VERSIONS
    """
}

process STRINGTIE_MERGE {
    tag "${meta.id}"
    label 'process_dual'

    input:
    tuple val(meta), path(gtfs, stageAs: 'assembled/*'), path(gtf)

    output:
    tuple val(meta), path("stringtie_merged.gtf"), emit: gtf
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    stringtie --merge \\
        -G ${gtf} \\
        -p ${task.cpus} \\
        -o stringtie_merged.gtf \\
        ${args} \\
        assembled/*.gtf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stringtie: \$( stringtie --version )
    END_VERSIONS
    """

    stub:
    """
    touch stringtie_merged.gtf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stringtie: stub
    END_VERSIONS
    """
}

process STRINGTIE_QUANT {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(bam), path(bai), path(gtf)

    output:
    tuple val(meta), path("${meta.id}", type: 'dir'), emit: ballgown
    tuple val(meta), path("*.gene_abund.tsv"), emit: gene_abundance
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    stringtie \\
        ${bam} \\
        -e -B \\
        -G ${gtf} \\
        -o ${meta.id}/${meta.id}.gtf \\
        -A ${meta.id}.gene_abund.tsv \\
        -p ${task.cpus} \\
        ${stringtieStrand(meta)} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stringtie: \$( stringtie --version )
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}
    touch ${meta.id}/t_data.ctab ${meta.id}.gene_abund.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        stringtie: stub
    END_VERSIONS
    """
}
