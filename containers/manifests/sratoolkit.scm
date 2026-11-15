(use-modules (sratoolkit))

(concatenate-manifests
  (list (packages->manifest (list sratoolkit))
        (specifications->manifest
          (list "pigz" "nss-certs" "bash" "coreutils" "findutils" "grep" "sed" "gawk" "procps" "gzip"))))
