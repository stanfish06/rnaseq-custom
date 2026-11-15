process SRATOOLKIT_SRASTAT {
    tag "${meta.id}"
    label 'process_mono'

    input:
    val meta

    output:
    tuple val(meta), path("*.sra-stat.xml"), emit: stat
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    mkdir -p .ncbi
    export NCBI_SETTINGS=\$PWD/.ncbi/user-settings.mkfg
    sra-stat --quick --xml ${args} ${meta.id} > ${meta.id}.sra-stat.xml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sratoolkit: \$( sra-stat --version | sed -n "s/.*sra-stat : //p" )
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}.sra-stat.xml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sratoolkit: stub
    END_VERSIONS
    """
}

process SRATOOLKIT_FASTERQDUMP {
    tag "${meta.id}"
    label 'process_quad'

    input:
    val meta

    output:
    tuple val(meta), path("*.fastq.gz"), emit: reads
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def max_reads = (params.download_max_reads ?: 0) as long
    def fetch = max_reads > 0 ? """
    fastq-dump --split-3 --skip-technical --maxSpotId ${max_reads} --outdir . ${meta.id}
    """ : """
    prefetch --max-size u --output-directory sra ${meta.id}
    fasterq-dump --split-3 --skip-technical --threads ${task.cpus} --temp tmp --outdir . ${args} sra/${meta.id}
    rm -rf sra tmp
    """
    """
    export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
    mkdir -p .ncbi
    export NCBI_SETTINGS=\$PWD/.ncbi/user-settings.mkfg
    ${fetch}
    pigz -p ${task.cpus} *.fastq

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sratoolkit: \$( fasterq-dump --version | sed -n "s/.*fasterq-dump : //p" )
    END_VERSIONS
    """

    stub:
    def files = meta.single_end ? "${meta.id}.fastq.gz" : "${meta.id}_1.fastq.gz ${meta.id}_2.fastq.gz"
    """
    for f in ${files}; do echo '' | gzip > \$f; done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        sratoolkit: stub
    END_VERSIONS
    """
}
