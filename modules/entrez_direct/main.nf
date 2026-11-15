process ENTREZ_DIRECT_RUNINFO {
    tag "${query}"
    label 'process_mono'
    maxForks 3

    input:
    val query

    output:
    path "*.runinfo.csv", emit: runinfo
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def name = query.replaceAll(/[^A-Za-z0-9_.-]/, '_')
    def max_runs = (params.download_max_runs ?: 0) as long
    def keep = max_runs > 0 ? "head -n ${max_runs + 1}" : 'cat'
    """
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    export CURL_CA_BUNDLE=\$SSL_CERT_FILE
    esearch -db sra -query '${query}' ${args} | efetch -format runinfo | awk 'NF' > all_runs.tmp
    ${keep} all_runs.tmp > ${name}.runinfo.csv
    test \$(wc -l < ${name}.runinfo.csv) -gt 1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        entrez-direct: \$( esearch -version )
    END_VERSIONS
    """

    stub:
    def name = query.replaceAll(/[^A-Za-z0-9_.-]/, '_')
    """
    printf 'Run,LibraryLayout,Experiment,SampleName,ScientificName\\n' > ${name}.runinfo.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        entrez-direct: stub
    END_VERSIONS
    """
}
