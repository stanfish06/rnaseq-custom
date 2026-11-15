(use-modules (fastq-screen))

(concatenate-manifests
  (list (packages->manifest (list fastq-screen))
        (specifications->manifest
          (list "bowtie" "perl" "bash" "coreutils" "findutils" "grep" "sed" "gawk" "procps" "gzip"))))
