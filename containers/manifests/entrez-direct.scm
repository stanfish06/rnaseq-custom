(use-modules (entrez-direct))

(concatenate-manifests
  (list (packages->manifest (list entrez-direct))
        (specifications->manifest
          (list "curl" "perl" "nss-certs" "bash" "coreutils" "findutils" "grep" "sed" "gawk" "procps" "gzip"))))
