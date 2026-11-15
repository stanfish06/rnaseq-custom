(define-module (fastq-screen)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages perl))

(define-public fastq-screen
  (package
    (name "fastq-screen")
    (version "0.16.0")
    (source
     (origin
       (method url-fetch)
       (uri (string-append
             "https://conda.anaconda.org/bioconda/noarch/fastq-screen-"
             version "-pl5321hdfd78af_0.tar.bz2"))
       (sha256
        (base32 "0xd1b6b1b23xa2qw88992l5b9l5jl5d73gwsavfw20003bjm8s2m"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan
      #~'((#$(string-append "share/fastq-screen-" version "-0/")
           "lib/fastq-screen/"
           #:include ("fastq_screen" "fastq_screen_summary_template.html"
                      "interactive_graphs.js" "OpenSans-Regular.ttf"
                      "FastQ_Screen_Logo.png" "fastq_screen.conf.example"
                      "license.txt")))
      #:phases
      #~(modify-phases %standard-phases
          (replace 'unpack
            (lambda* (#:key source #:allow-other-keys)
              (invoke "tar" "-xjf" source)))
          (add-after 'install 'link-bin
            (lambda _
              (let ((bin (string-append #$output "/bin")))
                (mkdir-p bin)
                (chmod (string-append #$output "/lib/fastq-screen/fastq_screen") #o755)
                (symlink (string-append #$output "/lib/fastq-screen/fastq_screen")
                         (string-append bin "/fastq_screen"))))))))
    (inputs (list perl))
    (home-page "https://www.bioinformatics.babraham.ac.uk/projects/fastq_screen/")
    (synopsis "Screen FASTQ reads against multiple reference genomes")
    (description
     "FastQ Screen maps a subset of reads to a panel of genomes to report the
fraction of reads originating from each species.")
    (license license:gpl3+)))
