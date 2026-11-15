#!/usr/bin/env bash
set -euo pipefail

image=${EDIRECT_IMAGE:-rnaseq/entrez-direct:26.6.20261102}
db=${SRA_DB:-sra}
columns=${SRA_COLUMNS:-Run,Experiment,SampleName,ScientificName,LibraryStrategy,LibrarySource,LibraryLayout,Platform,Model,spots,bases,avgLength,size_MB,BioProject,ReleaseDate}
max=${SRA_MAX:-500}

if [[ $# -lt 1 ]]; then
  cat >&2 <<EOF
usage: $(basename "$0") '<entrez query>' [out.csv]
  e.g. $(basename "$0") 'PRJNA123456'
       $(basename "$0") '"Homo sapiens"[Organism] AND "RNA-Seq"[Strategy] AND primordial germ cell' pgc.csv
env: SRA_COLUMNS (runinfo columns), SRA_MAX ($max), NCBI_API_KEY
EOF
  exit 1
fi

query=$1
out=${2:-}

result=$(docker run --rm \
  -e SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt \
  -e CURL_CA_BUNDLE=/etc/ssl/certs/ca-certificates.crt \
  -e NCBI_API_KEY="${NCBI_API_KEY:-}" \
  --entrypoint /bin/bash "$image" -c \
  'esearch -db "$1" -query "$2" | efetch -format runinfo | awk "NF"' _ "$db" "$query" \
  2> >(grep -v 'cannot find name for user ID' >&2) | awk -v max="$max" 'NR <= max + 1')

table=$(awk -F',' -v cols="$columns" '
  NR == 1 { n = split(cols, want, ","); for (i = 1; i <= NF; i++) idx[$i] = i }
  { line = ""; for (j = 1; j <= n; j++) line = line (j > 1 ? "," : "") (want[j] in idx ? $(idx[want[j]]) : ""); print line }
' <<<"$result")

if [[ -n $out ]]; then
  printf '%s\n' "$table" > "$out"
  awk -F',' 'NR > 1 && $1 ~ /^[SED]RR/ { print $1 }' "$out" > "${out%.csv}.accessions.txt"
  echo "[info] $(($(wc -l < "$out") - 1)) runs -> $out, accessions -> ${out%.csv}.accessions.txt" >&2
else
  printf '%s\n' "$table" | column -s, -t
fi
