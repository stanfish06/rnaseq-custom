(define-module (cufflinks)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression))

(define-public cufflinks
  (package
    (name "cufflinks")
    (version "2.2.1")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "http://cole-trapnell-lab.github.io/cufflinks/assets/downloads/cufflinks-"
             version ".Linux_x86_64.tar.gz"))
       (sha256
        (base32 "1r28cks50zx5ikm6vazrm8qfzs6r0j0x6w96blp4c9mf5i2i5y1r"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'(("cufflinks" "libexec/cufflinks/")
          ("cuffdiff" "libexec/cufflinks/")
          ("cuffquant" "libexec/cufflinks/")
          ("cuffnorm" "libexec/cufflinks/")
          ("cuffcompare" "libexec/cufflinks/")
          ("gtf_to_sam" "libexec/cufflinks/"))
      #:strip-binaries? #f
      #:validate-runpath? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'install 'make-launchers
            (lambda* (#:key inputs #:allow-other-keys)
              (let* ((ld (search-input-file inputs "lib/ld-linux-x86-64.so.2"))
                     (libs (string-join
                            (map (lambda (lib)
                                   (dirname (search-input-file inputs lib)))
                                 '("lib/libc.so.6" "lib/libz.so.1"))
                            ":"))
                     (bash (search-input-file inputs "bin/bash"))
                     (bin (string-append #$output "/bin")))
                (mkdir-p bin)
                (for-each
                 (lambda (name)
                   (let ((launcher (string-append bin "/" name)))
                     (call-with-output-file launcher
                       (lambda (port)
                         (format port "#!~a~%exec ~a --library-path ~a ~a/libexec/cufflinks/~a \"$@\"~%"
                                 bash ld libs #$output name)))
                     (chmod launcher #o755)))
                 '("cufflinks" "cuffdiff" "cuffquant" "cuffnorm"
                   "cuffcompare" "gtf_to_sam"))))))))
    (inputs (list bash-minimal glibc zlib))
    (home-page "http://cole-trapnell-lab.github.io/cufflinks/")
    (synopsis "Transcript assembly and differential expression")
    (description
     "Release binaries of cufflinks, cuffquant, cuffdiff, cuffnorm and
cuffcompare.  cuffmerge is omitted because it requires Python 2.")
    (license license:boost1.0)))
