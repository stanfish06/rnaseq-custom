process BALLGOWN {
    tag "${meta.id}"
    label 'process_dual'

    input:
    tuple val(meta), path(dirs, stageAs: 'ballgown/*'), val(design)

    output:
    tuple val(meta), path("ballgown.*.tsv"), emit: tables
    tuple val(meta), path("ballgown.rds"), emit: rds
    path "versions.yml", emit: versions

    script:
    """
    printf '%s\\n' ${design.collect { row -> "'${row}'" }.join(' ')} > design.csv

    Rscript - <<'EOF'
    suppressPackageStartupMessages(library(ballgown))
    design <- read.csv("design.csv", stringsAsFactors = FALSE)
    dirs <- file.path("ballgown", design\$sample)
    bg <- ballgown(samples = dirs, meas = "all")
    pData(bg) <- data.frame(id = design\$sample, condition = design\$condition)
    tx <- texpr(bg, "all")
    write.table(tx, "ballgown.transcript_fpkm.tsv", sep = "\\t", quote = FALSE, row.names = FALSE)
    gx <- gexpr(bg)
    write.table(data.frame(gene_id = rownames(gx), gx, check.names = FALSE), "ballgown.gene_fpkm.tsv", sep = "\\t", quote = FALSE, row.names = FALSE)
    if (length(unique(design\$condition)) >= 2 && nrow(design) > length(unique(design\$condition))) {
        de_tx <- stattest(bg, feature = "transcript", covariate = "condition", getFC = TRUE, meas = "FPKM")
        de_tx\$transcript_name <- transcriptNames(bg)[as.integer(de_tx\$id)]
        de_tx\$gene_id <- geneIDs(bg)[as.integer(de_tx\$id)]
        write.table(de_tx, "ballgown.transcript_de.tsv", sep = "\\t", quote = FALSE, row.names = FALSE)
        de_gene <- stattest(bg, feature = "gene", covariate = "condition", getFC = TRUE, meas = "FPKM")
        write.table(de_gene, "ballgown.gene_de.tsv", sep = "\\t", quote = FALSE, row.names = FALSE)
    }
    saveRDS(bg, "ballgown.rds")
    EOF

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-ballgown: \$( Rscript -e "cat(as.character(packageVersion('ballgown')))" )
    END_VERSIONS
    """

    stub:
    """
    touch ballgown.transcript_fpkm.tsv ballgown.gene_fpkm.tsv ballgown.rds

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        r-ballgown: stub
    END_VERSIONS
    """
}
