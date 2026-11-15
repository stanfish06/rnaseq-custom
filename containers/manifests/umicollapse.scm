(use-modules (umicollapse))

(concatenate-manifests
  (list (packages->manifest (list umicollapse))
        (specifications->manifest
          (list "samtools" "bash" "coreutils" "findutils" "grep" "sed" "gawk" "procps" "gzip"))))
