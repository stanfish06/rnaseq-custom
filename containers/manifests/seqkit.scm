(use-modules (seqkit))

(concatenate-manifests
  (list (packages->manifest (list seqkit))
        (specifications->manifest
          (list "bash" "coreutils" "findutils" "grep" "sed" "gawk" "procps" "gzip"))))
