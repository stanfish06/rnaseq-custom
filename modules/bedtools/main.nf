process BEDTOOLS_INTRONS {
    tag "${meta.id}"
    label 'process_mono'

    input:
    tuple val(meta), path(gtf)

    output:
    tuple val(meta), path("introns.saf"), emit: saf
    path "versions.yml", emit: versions

    script:
    """
    awk -F'\\t' 'BEGIN { OFS = "\\t" } \$3 == "gene" { match(\$9, /gene_id "[^"]+"/); id = substr(\$9, RSTART + 9, RLENGTH - 10); print \$1, \$4 - 1, \$5, id, ".", \$7 }' ${gtf} \\
        | sort -k1,1 -k2,2n > genes.bed
    awk -F'\\t' 'BEGIN { OFS = "\\t" } \$3 == "exon" { print \$1, \$4 - 1, \$5, ".", ".", \$7 }' ${gtf} \\
        | sort -k1,1 -k2,2n \\
        | bedtools merge -s -c 6 -o distinct -i - \\
        | awk 'BEGIN { OFS = "\\t" } { print \$1, \$2, \$3, ".", ".", \$4 }' > exons.bed
    bedtools subtract -s -a genes.bed -b exons.bed \\
        | awk 'BEGIN { OFS = "\\t"; print "GeneID", "Chr", "Start", "End", "Strand" } { print \$4, \$1, \$2 + 1, \$3, \$6 }' > introns.saf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: \$( bedtools --version | sed -e "s/bedtools v//g" )
    END_VERSIONS
    """

    stub:
    """
    touch introns.saf

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bedtools: stub
    END_VERSIONS
    """
}
