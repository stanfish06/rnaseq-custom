(define-module (umicollapse)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages java))

(define-public umicollapse
  (package
    (name "umicollapse")
    (version "1.1.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://conda.anaconda.org/bioconda/noarch/umicollapse-"
             version "-hdfd78af_0.tar.bz2"))
       (sha256
        (base32 "1sxnvdhcx2kyq53cr5mbip6njb3s9chjdnwfxh86dpl54s09q0wp"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'((#$(string-append "share/umicollapse-" version "-0/umicollapse.jar")
           "lib/umicollapse/")
          (#$(string-append "share/umicollapse-" version "-0/lib")
           "lib/umicollapse/lib"))
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (invoke "tar" "-xjf" source)))
          (add-after 'install 'make-launcher
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((bin (string-append #$output "/bin/umicollapse"))
                    (java (search-input-file inputs "bin/java"))
                    (bash (search-input-file inputs "bin/bash")))
                (mkdir-p (dirname bin))
                (call-with-output-file bin
                  (lambda (port)
                    (format port "#!~a~%exec ~a ${UMICOLLAPSE_JAVA_OPTS:--Xms2g -Xmx8g -Xss1G} -jar ~a/lib/umicollapse/umicollapse.jar \"$@\"~%"
                            bash java #$output)))
                (chmod bin #o755)))))))
    (inputs (list bash-minimal openjdk17))
    (home-page "https://github.com/Daniel-Liu-c0deb0t/UMICollapse")
    (synopsis "Fast UMI deduplication")
    (description
     "Bioconda build of the UMICollapse jar with a launcher script.  Java
options are read from UMICOLLAPSE_JAVA_OPTS.")
    (license license:expat)))
