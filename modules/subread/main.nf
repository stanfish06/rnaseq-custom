process SUBREAD_FEATURECOUNTS {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(annotation), path(bams, stageAs: 'bams/*')

    output:
    tuple val(meta), path("*.featureCounts.tsv"), emit: counts
    tuple val(meta), path("*.featureCounts.tsv.summary"), emit: summary
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def extra = meta.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def paired = meta.single_end ? '' : '-p --countReadPairs'
    def strand = [unstranded: 0, forward: 1, reverse: 2][meta.strandedness] ?: 0
    def name = annotation.name
    def plain = name.endsWith('.gz') ? name[0..<-3] : name
    def decompress = name.endsWith('.gz') ? "gzip -dc ${name} > ${plain}" : ''
    def is_bed = plain.endsWith('.bed')
    def is_saf = plain.endsWith('.saf')
    def to_saf = is_bed ? """
    awk -F'\\t' 'BEGIN { OFS = "\\t"; print "GeneID", "Chr", "Start", "End", "Strand" } !/^(#|track|browser)/ { id = (NF >= 4 && \$4 != "." ? \$4 : \$1 ":" \$2 + 1 "-" \$3); s = (NF >= 6 && \$6 ~ /^[+-]\$/ ? \$6 : "+"); print id, \$1, \$2 + 1, \$3, s }' ${plain} > ${prefix}.saf
    """ : ''
    def anno = is_bed ? "${prefix}.saf" : plain
    def format = (is_bed || is_saf) ? '-F SAF' : ''
    """
    ${decompress}
    ${to_saf}
    featureCounts \\
        ${paired} \\
        ${format} \\
        -s ${strand} \\
        -T ${task.cpus} \\
        ${extra} \\
        ${args} \\
        -a ${anno} \\
        -o ${prefix}.featureCounts.tsv \\
        bams/*.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        subread: \$( featureCounts -v 2>&1 | sed -n "s/featureCounts v//p" )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.featureCounts.tsv ${prefix}.featureCounts.tsv.summary

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        subread: stub
    END_VERSIONS
    """
}
