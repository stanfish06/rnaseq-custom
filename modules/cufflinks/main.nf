def cufflinksLibraryType(meta) {
    return [forward: 'fr-secondstrand', reverse: 'fr-firststrand'][meta.strandedness] ?: 'fr-unstranded'
}

process CUFFLINKS_CUFFQUANT {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(bam), path(bai), path(gtf)

    output:
    tuple val(meta), path("*.cxb"), emit: cxb
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    cuffquant \\
        --num-threads ${task.cpus} \\
        --library-type ${cufflinksLibraryType(meta)} \\
        --output-dir cuffquant \\
        ${args} \\
        ${gtf} \\
        ${bam}
    mv cuffquant/abundances.cxb ${prefix}.cxb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cufflinks: \$( cuffquant 2>&1 | sed -n "1s/cuffquant v//p" )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.cxb

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cufflinks: stub
    END_VERSIONS
    """
}

process CUFFLINKS_CUFFDIFF {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(cxbs, stageAs: 'cxb/*'), val(labels), val(groups), val(library_type), path(gtf)

    output:
    tuple val(meta), path("cuffdiff"), emit: results
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def tool = labels.size() >= 2 ? 'cuffdiff' : 'cuffnorm'
    def replicates = groups.collect { g -> g.split(',').collect { s -> "cxb/${s}.cxb" }.join(',') }.join(' ')
    """
    ${tool} \\
        --num-threads ${task.cpus} \\
        --library-type ${library_type} \\
        --output-dir cuffdiff \\
        --labels ${labels.join(',')} \\
        ${args} \\
        ${gtf} \\
        ${replicates}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cufflinks: \$( ${tool} 2>&1 | sed -n "1s/${tool} v//p" )
    END_VERSIONS
    """

    stub:
    """
    mkdir -p cuffdiff
    touch cuffdiff/genes.fpkm_tracking

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        cufflinks: stub
    END_VERSIONS
    """
}
