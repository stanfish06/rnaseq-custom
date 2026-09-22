#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dest=$root/data/test
base=data/genomics/sarscov2
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

git clone -q --depth 1 --branch modules --filter=blob:none --sparse https://github.com/nf-core/test-datasets "$tmp"
git -C "$tmp" sparse-checkout set "$base/illumina/fastq" "$base/illumina/bam" "$base/genome" >/dev/null

mkdir -p "$dest"
for f in test_1 test_2 test2_1 test2_2; do
  cp "$tmp/$base/illumina/fastq/$f.fastq.gz" "$dest/"
done
cp "$tmp/$base/illumina/bam/test.paired_end.sorted.bam" "$tmp/$base/illumina/bam/test.paired_end.sorted.bam.bai" "$dest/"
cp "$tmp/$base/genome/genome.gtf" "$dest/"

awk -F'\t' 'BEGIN { OFS = "\t" } /^#/ { print; next } { print } $3 == "CDS" { $3 = "exon"; print }' \
  "$dest/genome.gtf" > "$dest/genome.exon.gtf"

ls -l "$dest"
