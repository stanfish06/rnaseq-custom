#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
refs=${REFS_DIR:-$root/data/refs}

gencode_human=https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_human/release_49
gencode_mouse=https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M38
ensembl=https://ftp.ensembl.org/pub/release-115
ucsc_hg38=https://hgdownload.soe.ucsc.edu/goldenPath/hg38/chromosomes

smoke_chrom=chr22
promoter_upstream=2000

declare -A fasta_url=(
  [human]=$gencode_human/GRCh38.primary_assembly.genome.fa.gz
  [mouse]=$gencode_mouse/GRCm39.primary_assembly.genome.fa.gz
  [macaque]=$ensembl/fasta/macaca_mulatta/dna/Macaca_mulatta.Mmul_10.dna.toplevel.fa.gz
  [yeast]=$ensembl/fasta/saccharomyces_cerevisiae/dna/Saccharomyces_cerevisiae.R64-1-1.dna.toplevel.fa.gz
)
declare -A gtf_url=(
  [human]=$gencode_human/gencode.v49.primary_assembly.annotation.gtf.gz
  [mouse]=$gencode_mouse/gencode.vM38.primary_assembly.annotation.gtf.gz
  [macaque]=$ensembl/gtf/macaca_mulatta/Macaca_mulatta.Mmul_10.115.gtf.gz
  [yeast]=$ensembl/gtf/saccharomyces_cerevisiae/Saccharomyces_cerevisiae.R64-1-1.115.gtf.gz
)

fetch() {
  local url=$1 dest=$2
  if [[ -s $dest ]]; then
    echo "[skip] $dest"
    return
  fi
  echo "[get] $url"
  curl -fsSL --retry 3 "$url" | gzip -dc > "$dest.part"
  mv "$dest.part" "$dest"
}

promoters() {
  local gtf=$1 out=$2
  awk -F'\t' -v up="$promoter_upstream" 'BEGIN { OFS = "\t" }
    $3 == "gene" {
      match($9, /gene_id "[^"]+"/); id = substr($9, RSTART + 9, RLENGTH - 10)
      if ($7 == "+") { s = $4 - 1 - up; e = $4 - 1 } else { s = $5; e = $5 + up }
      if (s < 0) s = 0
      print $1, s, e, id "_promoter", ".", $7
    }' "$gtf" | sort -k1,1 -k2,2n > "$out"
}

smoke() {
  local dest=$refs/smoke
  mkdir -p "$dest"
  fetch "$ucsc_hg38/$smoke_chrom.fa.gz" "$dest/$smoke_chrom.fa"
  if [[ ! -s $dest/$smoke_chrom.gtf ]]; then
    echo "[get] ${gtf_url[human]} ($smoke_chrom only)"
    curl -fsSL --retry 3 "${gtf_url[human]}" | gzip -dc | awk -F'\t' -v c="$smoke_chrom" '/^#/ || $1 == c' > "$dest/$smoke_chrom.gtf.part"
    mv "$dest/$smoke_chrom.gtf.part" "$dest/$smoke_chrom.gtf"
  fi
  fetch "${fasta_url[yeast]}" "$dest/yeast_R64.fa"
  promoters "$dest/$smoke_chrom.gtf" "$dest/promoter_${promoter_upstream}.$smoke_chrom.bed"
  ls -l "$dest"
}

genome() {
  local name=$1
  if [[ -z ${fasta_url[$name]:-} ]]; then
    echo "unknown genome '$name', expected one of: ${!fasta_url[*]}" >&2
    exit 1
  fi
  local dest=$refs/$name
  mkdir -p "$dest"
  fetch "${fasta_url[$name]}" "$dest/genome.fa"
  fetch "${gtf_url[$name]}" "$dest/genes.gtf"
  ls -l "$dest"
}

target=${1:-smoke}
shift || true
case $target in
  smoke) smoke ;;
  genome)
    if [[ $# -eq 0 ]]; then
      set -- "${!fasta_url[@]}"
    fi
    for g in "$@"; do genome "$g"; done
    ;;
  *)
    echo "usage: $0 [smoke | genome [human|mouse|macaque|yeast ...]]" >&2
    exit 1
    ;;
esac
