def curlCap(max_reads, url, out) {
    return """
    { curl -fsSL --retry 5 --retry-all-errors "${url}" | gzip -dc | head -n ${max_reads * 4}; } 2>/dev/null | gzip > "${out}" || true
    gzip -t "${out}"
    """
}

process CURL_BIOSTUDIES {
    tag "${query}"
    label 'process_mono'
    maxForks 3

    input:
    val query

    output:
    tuple val(query), path("*.ena.txt"), emit: ena
    path "versions.yml", emit: versions

    script:
    """
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    curl -fsSL --retry 5 --retry-all-errors "https://www.ebi.ac.uk/biostudies/api/v1/studies/${query}" \\
        | jq -r '[.. | objects | select(.url? and ((.attributes? // []) | any(.name == "Type" and .value == "ENA"))) | .url] | unique | .[]' \\
        > ${query}.ena.txt
    test -s ${query}.ena.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: \$( curl --version | sed -n "1s/curl \\([^ ]*\\).*/\\1/p" )
    END_VERSIONS
    """

    stub:
    """
    echo ERP000000 > ${query}.ena.txt

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: stub
    END_VERSIONS
    """
}

process CURL_ENAFILEREPORT {
    tag "${query}"
    label 'process_mono'
    maxForks 3

    input:
    val query

    output:
    path "*.runinfo.csv", emit: runinfo
    path "versions.yml", emit: versions

    script:
    def max_runs = (params.download_max_runs ?: 0) as long
    def keep = max_runs > 0 ? "head -n ${max_runs + 1}" : 'cat'
    def limit = max_runs > 0 ? "&limit=${max_runs}" : ''
    """
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    curl -fsSL --http1.1 --retry 5 --retry-all-errors "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${query}&result=read_run&format=tsv${limit}&fields=run_accession,library_layout,experiment_accession,sample_alias,sample_title,scientific_name,read_count,base_count" \\
        | awk -F'\\t' 'BEGIN { OFS = "," } NR == 1 { print "Run", "LibraryLayout", "Experiment", "SampleName", "ScientificName", "spots", "bases"; next } { for (i = 1; i <= NF; i++) gsub(/,/, ";", \$i); print \$1, \$2, \$3, (\$5 != "" ? \$5 : \$4), \$6, \$7, \$8 }' \\
        > all_runs.tmp
    ${keep} all_runs.tmp > ${query}.runinfo.csv
    test \$(wc -l < ${query}.runinfo.csv) -gt 1

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: \$( curl --version | sed -n "1s/curl \\([^ ]*\\).*/\\1/p" )
    END_VERSIONS
    """

    stub:
    """
    printf 'Run,LibraryLayout,Experiment,SampleName,ScientificName,spots,bases\\n' > ${query}.runinfo.csv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: stub
    END_VERSIONS
    """
}

process CURL_ENAFASTQ {
    tag "${meta.id}"
    label 'process_mono'
    maxForks 4
    errorStrategy 'retry'
    maxRetries 2

    input:
    val meta

    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads, optional: true
    tuple val(meta), path("no_ena_fastq"), emit: missing, optional: true
    path "versions.yml", emit: versions

    script:
    def max_reads = (params.download_max_reads ?: 0) as long
    def strict = params.download_source == 'ena' ? 'exit 1' : 'touch no_ena_fastq'
    def fetch = max_reads > 0 ? curlCap(max_reads, 'https://${urls[i]}', '\${name}') : '''
        curl -fsSL --retry 5 --retry-all-errors -o "${name}" "https://${urls[i]}"
        echo "${md5s[i]}  ${name}" | md5sum -c -
    '''
    """
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    curl -fsSL --retry 5 --retry-all-errors "https://www.ebi.ac.uk/ena/portal/api/filereport?accession=${meta.id}&result=read_run&format=tsv&fields=fastq_ftp,fastq_md5" \\
        | awk -F'\\t' 'BEGIN { OFS = "\\t" } NR == 1 { for (i = 1; i <= NF; i++) col[\$i] = i; next } NR == 2 { print \$col["fastq_ftp"], \$col["fastq_md5"] }' > report.tsv
    IFS=';' read -r -a all_urls <<< "\$(cut -f1 report.tsv)"
    IFS=';' read -r -a all_md5s <<< "\$(cut -f2 report.tsv)"
    urls=(); md5s=()
    for i in "\${!all_urls[@]}"; do
        case "\${all_urls[\$i]}" in *_1.fastq.gz|*_2.fastq.gz) urls+=("\${all_urls[\$i]}"); md5s+=("\${all_md5s[\$i]}") ;; esac
    done
    if [ \${#urls[@]} -ne 2 ]; then
        urls=("\${all_urls[@]}"); md5s=("\${all_md5s[@]}")
    fi
    if [ \${#urls[@]} -eq 0 ] || [ -z "\${urls[0]:-}" ]; then
        ${strict}
    else
        for i in "\${!urls[@]}"; do
            name=\$(basename "\${urls[\$i]}")
            ${fetch}
        done
        ls *.fastq.gz > /dev/null
    fi

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: \$( curl --version | sed -n "1s/curl \\([^ ]*\\).*/\\1/p" )
    END_VERSIONS
    """

    stub:
    """
    echo '' | gzip > ${meta.id}.fastq.gz

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: stub
    END_VERSIONS
    """
}

process CURL_ZENODORECORD {
    tag "${record}"
    label 'process_mono'
    maxForks 3

    input:
    val record

    output:
    path "*.files.tsv", emit: files
    path "versions.yml", emit: versions

    script:
    """
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    curl -fsSL --retry 5 --retry-all-errors "https://zenodo.org/api/records/${record}" \\
        | jq -r --arg pattern '${params.zenodo_pattern}' '.id as \$id | .files[] | select(.key | test(\$pattern)) | [\$id, .key, .size, (.checksum | sub("^md5:"; "")), .links.self] | @tsv' \\
        > ${record}.files.tsv
    test -s ${record}.files.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: \$( curl --version | sed -n "1s/curl \\([^ ]*\\).*/\\1/p" )
    END_VERSIONS
    """

    stub:
    """
    printf '${record}\\tstub_R1.fastq.gz\\t1\\tx\\thttps://example\\n' > ${record}.files.tsv

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: stub
    END_VERSIONS
    """
}

process CURL_ZENODOFILE {
    tag "${file_meta.name}"
    label 'process_mono'
    maxForks 4
    errorStrategy 'retry'
    maxRetries 2

    input:
    val file_meta

    output:
    tuple val(file_meta), path("${file_meta.name}"), emit: file
    path "versions.yml", emit: versions

    script:
    def max_reads = (params.download_max_reads ?: 0) as long
    def fetch = max_reads > 0 ? curlCap(max_reads, file_meta.url, file_meta.name) : """
    curl -fsSL --retry 5 --retry-all-errors -o "${file_meta.name}" "${file_meta.url}"
    echo "${file_meta.md5}  ${file_meta.name}" | md5sum -c -
    """
    """
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    ${fetch}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: \$( curl --version | sed -n "1s/curl \\([^ ]*\\).*/\\1/p" )
    END_VERSIONS
    """

    stub:
    """
    echo '' | gzip > ${file_meta.name}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        curl: stub
    END_VERSIONS
    """
}
