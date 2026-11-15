(use-modules (gedi))

(concatenate-manifests
  (list (packages->manifest (list gedi))
        (specifications->manifest
          (list "samtools" "bash" "coreutils" "findutils" "grep" "sed" "gawk" "procps" "gzip"))))
