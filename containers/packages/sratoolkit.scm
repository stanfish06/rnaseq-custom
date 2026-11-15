(define-module (sratoolkit)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)
  #:use-module (gnu packages elf))

(define-public sratoolkit
  (package
    (name "sratoolkit")
    (version "3.4.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://ftp-trace.ncbi.nlm.nih.gov/sra/sdk/"
                           version "/sratoolkit." version "-ubuntu64.tar.gz"))
       (sha256
        (base32 "15imvdrh42yb1ry02qj8jr7fjh7h4bq4f6gl98ca8ra70ln3cl5r"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan #~'(("bin" "bin"))
      #:strip-binaries? #f
      #:validate-runpath? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'patchelf
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((ld (search-input-file inputs "lib/ld-linux-x86-64.so.2"))
                    (rpath (dirname (search-input-file inputs "lib/libc.so.6"))))
                (for-each
                 (lambda (file)
                   (when (and (not (symbolic-link? file)) (elf-file? file))
                     (invoke "patchelf" "--set-interpreter" ld
                             "--set-rpath" rpath file)))
                 (find-files (string-append #$output "/bin")))))))))
    (native-inputs (list patchelf))
    (inputs (list glibc))
    (home-page "https://github.com/ncbi/sra-tools")
    (synopsis "NCBI SRA Toolkit")
    (description
     "Release binaries of prefetch, fasterq-dump, fastq-dump, sra-stat and
vdb-config for downloading and inspecting SRA runs.")
    (license license:public-domain)))
