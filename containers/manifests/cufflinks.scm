(use-modules (cufflinks))

(concatenate-manifests
  (list (packages->manifest (list cufflinks))
        (specifications->manifest
          (list "bash" "coreutils" "findutils" "grep" "sed" "gawk" "procps" "gzip"))))
