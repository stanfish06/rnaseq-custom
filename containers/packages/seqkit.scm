(define-module (seqkit)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system copy))

(define-public seqkit
  (package
    (name "seqkit")
    (version "2.14.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/shenwei356/seqkit/releases/download/v"
             version "/seqkit_linux_amd64.tar.gz"))
       (file-name (string-append name "-" version "-linux-amd64.tar.gz"))
       (sha256
        (base32 "1dc6zz6pzsjajivciw9mcji6h0yhf460dz1w7yyiz3a393xlyrix"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan #~'(("seqkit" "bin/"))
      #:strip-binaries? #f
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (invoke "tar" "-xzf" source))))))
    (home-page "https://bioinf.shenwei.me/seqkit/")
    (synopsis "FASTA/Q toolkit")
    (description "Static release binary of SeqKit for FASTA/Q manipulation.")
    (license license:expat)))
