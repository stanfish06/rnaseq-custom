(define-module (gedi)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages java))

(define-public gedi
  (package
    (name "gedi")
    (version "1.0.6a")
    (source
     (origin
       (method url-fetch)
       (uri (string-append "https://conda.anaconda.org/bioconda/noarch/gedi-"
                           version "-hdfd78af_1.conda"))
       (sha256
        (base32 "1h5ybrjbsq2lbsw585yi279ybjs9k1jxc3qhwasklmd3hnrdqm64"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'((#$(string-append "share/gedi-" version "-1/") "lib/gedi/"))
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (invoke "unzip" "-q" source)
              (invoke "tar" "--zstd" "-xf"
                      #$(string-append "pkg-gedi-" version "-hdfd78af_1.tar.zst"))))
          (add-after 'install 'wrap
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((lib (string-append #$output "/lib/gedi"))
                    (bin (string-append #$output "/bin"))
                    (jdk (dirname (dirname (search-input-file inputs "bin/java")))))
                (mkdir-p bin)
                (for-each
                 (lambda (name)
                   (wrap-program (string-append lib "/" name)
                     `("JAVA_HOME" = (,jdk))
                     `("PATH" prefix
                       (,bin ,(string-append jdk "/bin")
                             ,(dirname (search-input-file inputs "bin/grep"))
                             ,(dirname (search-input-file inputs "bin/dirname")))))
                   (symlink (string-append lib "/" name)
                            (string-append bin "/" name)))
                 '("gedi" "bamlist2cit"))))))))
    (native-inputs (list unzip zstd))
    (inputs (list bash-minimal coreutils grep openjdk17))
    (home-page "https://github.com/erhard-lab/gedi")
    (synopsis "Genomic data framework including GRAND-SLAM")
    (description
     "Bioconda build of GEDI jars with launchers for gedi and bamlist2cit,
including GRAND-SLAM for nucleotide-conversion RNA-seq.")
    (license license:asl2.0)))
