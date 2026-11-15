process TXIMPORT_TX2GENE {
    tag "${meta.id}"
    label 'process_mono'

    input:
    tuple val(meta), path(gtf)

    output:
    tuple val(meta), path("tx2gene.tsv"), emit: tx2gene
    path "versions.yml", emit: versions

    script:
    """
    awk -F'\\t' 'BEGIN { OFS = "\\t"; print "transcript_id", "gene_id", "gene_name" }
        \$3 == "transcript" || \$3 == "exon" {
            if (!match(\$9, /transcript_id "[^"]+"/)) next
            tx = substr(\$9, RSTART + 15, RLENGTH - 16)
            if (tx in seen) next
            match(\$9, /gene_id "[^"]+"/); gene = substr(\$9, RSTART + 9, RLENGTH - 10)
            name = match(\$9, /gene_name "[^"]+"/) ? substr(\$9, RSTART + 11, RLENGTH - 12) : gene
            seen[tx] = 1
            print tx, gene, name
        }' ${gtf} > tx2gene.tsv
    test \$(wc -l < tx2gene.tsv) -gt 1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: \$( awk --version | sed -n "1s/GNU Awk \\([^,]*\\).*/\\1/p" )
    END_VERSIONS
    """

    stub:
    """
    printf 'transcript_id\\tgene_id\\tgene_name\\n' > tx2gene.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gawk: stub
    END_VERSIONS
    """
}

process TXIMPORT_MERGE {
    tag "${meta.id}"
    label 'process_dual'

    input:
    tuple val(meta), val(samples), path(quants, stageAs: 'quant/?/*'), path(tx2gene), path(script)

    output:
    tuple val(meta), path("*.merged.*.tsv"), emit: tables
    path "versions.yml", emit: versions

    script:
    def files = quants instanceof List ? quants : [quants]
    def pairs = [samples, files].transpose().collect { s ->
        def target = meta.quantifier == 'salmon' ? "${s[1]}/quant.sf" : "${s[1]}"
        "'${s[0]}=${target}'"
    }.join(' ')
    """
    Rscript ${script} ${meta.quantifier} ${meta.quantifier}.merged ${tx2gene} ${pairs}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-tximport: \$( Rscript -e "cat(as.character(packageVersion('tximport')))" )
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.quantifier}.merged.gene_counts.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-tximport: stub
    END_VERSIONS
    """
}
