(define-module (entrez-direct)
  #:use-module (guix packages)
  #:use-module (guix download)
  #:use-module (guix gexp)
  #:use-module ((guix licenses) #:prefix license:)
  #:use-module (guix build-system copy)
  #:use-module (gnu packages base)
  #:use-module (gnu packages bash)
  #:use-module (gnu packages compression)
  #:use-module (gnu packages elf)
  #:use-module (gnu packages perl))

(define %edirect-version "26.6.20261102")

(define (edirect-url file)
  (string-append "https://ftp.ncbi.nlm.nih.gov/entrez/entrezdirect/versions/"
                 %edirect-version "/" file))

(define (edirect-go-binary name hash)
  (origin
    (method url-fetch)
    (uri (edirect-url (string-append name ".Linux.gz")))
    (file-name (string-append name ".Linux-" %edirect-version ".gz"))
    (sha256 (base32 hash))))

(define %xtract
  (edirect-go-binary "xtract" "0p1vjg8nl70gpkg5c4spf590yqxw3klbqqjb4a2pahvvdjf9smm7"))

(define %transmute
  (edirect-go-binary "transmute" "0lk8nbz8kqq99wzgy6rmaf01r72n9m66gmr6dana4n4jzxl97hmg"))

(define %rchive
  (edirect-go-binary "rchive" "0sfhxkyr1fc03hgfgxx8v6x2h2awcrspkwwanq5zvq0dn8ak855v"))

(define-public entrez-direct
  (package
    (name "entrez-direct")
    (version %edirect-version)
    (source
     (origin
       (method url-fetch)
       (uri (edirect-url (string-append "edirect-" version ".tar.gz")))
       (sha256
        (base32 "0nzifhh5d34sfn9593k7d9hlyjx8wn4d378x26g1gqf1jmzz0nn4"))))
    (build-system copy-build-system)
    (arguments
     (list
      #:install-plan #~'(("." "bin"))
      #:strip-binaries? #f
      #:validate-runpath? #f
      #:phases
      #~(modify-phases %standard-phases
          (add-after 'unpack 'add-go-binaries
            (lambda _
              (for-each
               (lambda (name gz)
                 (copy-file gz (string-append name ".Linux.gz"))
                 (invoke "gunzip" "-f" (string-append name ".Linux.gz"))
                 (chmod (string-append name ".Linux") #o755))
               '("xtract" "transmute" "rchive")
               (list #$%xtract #$%transmute #$%rchive))))
          (add-after 'install 'patchelf
            (lambda* (#:key inputs #:allow-other-keys)
              (let ((ld (search-input-file inputs "lib/ld-linux-x86-64.so.2"))
                    (rpath (dirname (search-input-file inputs "lib/libc.so.6"))))
                (for-each
                 (lambda (name)
                   (invoke "patchelf" "--set-interpreter" ld "--set-rpath" rpath
                           (string-append #$output "/bin/" name ".Linux")))
                 '("xtract" "transmute" "rchive"))))))))
    (native-inputs (list patchelf gzip))
    (inputs (list glibc bash-minimal perl))
    (home-page "https://www.ncbi.nlm.nih.gov/books/NBK179288/")
    (synopsis "NCBI Entrez Direct E-utilities")
    (description
     "esearch, efetch, elink, efilter, esummary and xtract for querying NCBI
Entrez databases from the command line.")
    (license license:public-domain)))
