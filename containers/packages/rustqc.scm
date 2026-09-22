(define-module (rustqc)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages fontutils)
  #:use-module (gnu packages gcc))

(define-public rustqc
  (package
    (name "rustqc")
    (version "0.2.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://github.com/seqeralabs/RustQC/releases/download/v"
             version "/rustqc-linux-x86_64.tar.gz"))
       (sha256
        (base32 "0jl0pxw408afdirrxl46n218nkxsa1cggwskmxpf1snvljb2x9rg"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan #~'(("rustqc" "bin/"))
      #:strip-binaries? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'patchelf
            (lambda* (#:key inputs outputs #:allow-other-keys)
              (let ((bin (string-append #$output "/bin/rustqc"))
                    (ld (search-input-file inputs "lib/ld-linux-x86-64.so.2"))
                    (rpath (string-join
                            (map (lambda (lib)
                                   (dirname (search-input-file inputs lib)))
                                 '("lib/libc.so.6"
                                   "lib/libstdc++.so.6"
                                   "lib/libfreetype.so.6"
                                   "lib/libfontconfig.so.1"))
                            ":")))
                (invoke "patchelf" "--set-interpreter" ld "--set-rpath" rpath bin)))))))
    (native-inputs (list patchelf))
    (inputs (list glibc `(,gcc "lib") freetype fontconfig))
    (home-page "https://github.com/seqeralabs/RustQC")
    (synopsis "RNA-seq QC tools in one binary")
    (description
     "Fast genomics quality control tools for sequencing data, written in Rust.")
    (license license:gpl3+)))
