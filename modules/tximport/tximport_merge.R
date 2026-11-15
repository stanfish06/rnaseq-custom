suppressPackageStartupMessages(library(tximport))

args <- commandArgs(trailingOnly = TRUE)
if (length(args) < 4) {
  stop("usage: tximport_merge.R <salmon|rsem> <out_prefix> <tx2gene.tsv> <sample=path> [sample=path ...]")
}
quant_type <- args[[1]]
out_file_prefix <- args[[2]]
tinfo_path <- args[[3]]
pairs <- strsplit(args[-(1:3)], "=", fixed = TRUE)
fns <- vapply(pairs, function(p) p[[2]], character(1))
names(fns) <- vapply(pairs, function(p) p[[1]], character(1))
if (!quant_type %in% c("salmon", "rsem")) {
  stop("type must be salmon or rsem, got ", quant_type)
}
missing <- fns[!file.exists(fns)]
if (length(missing) > 0) {
  stop("missing input files: ", paste(missing, collapse = ", "))
}
message("Samples: ", paste(names(fns), collapse = ", "))

read_transcript_info <- function(tinfo_path, tximport_obj) {
  if (file.info(tinfo_path)$size == 0) {
    stop("tx2gene file is empty")
  }
  transcript_info <- read.csv(
    tinfo_path,
    sep = "\t",
    header = TRUE,
    col.names = c("tx", "gene_id", "gene_name")
  )
  extra <- setdiff(rownames(tximport_obj[[1]]), as.character(transcript_info[["tx"]]))
  if (length(extra) > 0) {
    message(length(extra), " transcript(s) missing from tx2gene; using transcript id as gene")
  }
  transcript_info <- rbind(
    transcript_info,
    data.frame(tx = extra, gene_id = extra, gene_name = extra)
  )
  transcript_info <- transcript_info[match(rownames(tximport_obj[[1]]), transcript_info[["tx"]]), ]
  rownames(transcript_info) <- transcript_info[["tx"]]
  list(
    transcript = transcript_info,
    gene = unique(transcript_info[, 2:3]),
    tx2gene = transcript_info[, 1:2]
  )
}

build_table <- function(data, row_meta) {
  data.frame(cbind(row_meta, data), check.names = FALSE)
}

write_table <- function(out_file, file_prefix) {
  file_name <- paste0(file_prefix, ".", out_file$out_file_suffix)
  message("Writing ", file_name)
  write.table(
    build_table(out_file$data, out_file$row_meta),
    file_name,
    sep = "\t",
    quote = FALSE,
    row.names = FALSE
  )
}

message("Running tximport (type = ", quant_type, ", txOut = TRUE)...")
txi <- if (quant_type == "salmon") {
  tximport(fns, type = "salmon", txOut = TRUE, dropInfReps = FALSE)
} else {
  tximport(fns, type = "rsem", txIn = TRUE, txOut = TRUE)
}
message("tximport complete: ", nrow(txi[["counts"]]), " transcripts x ", ncol(txi[["counts"]]), " samples")

transcript_info <- read_transcript_info(tinfo_path = tinfo_path, tximport_obj = txi)
message(
  "tx2gene mapping loaded: ", nrow(transcript_info$tx2gene), " transcripts, ",
  nrow(transcript_info$gene), " genes"
)

out_files <- list(
  list(data = txi[["abundance"]], row_meta = transcript_info$transcript, out_file_suffix = "transcript_tpm.tsv"),
  list(data = txi[["counts"]], row_meta = transcript_info$transcript, out_file_suffix = "transcript_counts.tsv"),
  list(data = txi[["length"]], row_meta = transcript_info$transcript, out_file_suffix = "transcript_lengths.tsv")
)

tx2gene <- transcript_info$tx2gene
gi <- summarizeToGene(txi, tx2gene = tx2gene)
gi.ls <- summarizeToGene(txi, tx2gene = tx2gene, countsFromAbundance = "lengthScaledTPM")
gi.s <- summarizeToGene(txi, tx2gene = tx2gene, countsFromAbundance = "scaledTPM")
message("Gene-level summarization complete: ", nrow(gi[["counts"]]), " genes")

gene_info <- transcript_info$gene[match(rownames(gi[[1]]), transcript_info$gene[["gene_id"]]), ]
rownames(gene_info) <- NULL
out_files <- c(out_files, list(
  list(data = gi[["length"]], row_meta = gene_info, out_file_suffix = "gene_lengths.tsv"),
  list(data = gi[["abundance"]], row_meta = gene_info, out_file_suffix = "gene_tpm.tsv"),
  list(data = gi[["counts"]], row_meta = gene_info, out_file_suffix = "gene_counts.tsv"),
  list(data = gi.ls[["counts"]], row_meta = gene_info, out_file_suffix = "gene_counts_length_scaled.tsv"),
  list(data = gi.s[["counts"]], row_meta = gene_info, out_file_suffix = "gene_counts_scaled.tsv")
))

if (quant_type == "rsem") {
  fpkm_tx <- do.call(cbind, lapply(fns, function(f) {
    d <- read.delim(f, check.names = FALSE)
    setNames(d[["FPKM"]], d[["transcript_id"]])[rownames(txi[["counts"]])]
  }))
  colnames(fpkm_tx) <- names(fns)
  fpkm_gene <- rowsum(fpkm_tx, transcript_info$tx2gene[rownames(fpkm_tx), "gene_id"])
  out_files <- c(out_files, list(
    list(data = fpkm_tx, row_meta = transcript_info$transcript, out_file_suffix = "transcript_fpkm.tsv"),
    list(
      data = fpkm_gene,
      row_meta = transcript_info$gene[match(rownames(fpkm_gene), transcript_info$gene[["gene_id"]]), ],
      out_file_suffix = "gene_fpkm.tsv"
    )
  ))
}

message("Writing ", length(out_files), " output table(s)...")
invisible(lapply(out_files, write_table, out_file_prefix))
message("Done.")
