(use-modules (rustqc))

(concatenate-manifests
  (list (packages->manifest (list rustqc))
        (specifications->manifest
          (list "font-dejavu"
                "bash"
                "coreutils"
                "findutils"
                "grep"
                "sed"
                "gawk"
                "procps"))))
