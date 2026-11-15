process FASTQ_SCREEN_INDEX {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(fasta)

    output:
    tuple val(meta), path("${meta.id}", type: 'dir'), emit: index
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    """
    mkdir -p ${meta.id}
    bowtie2-build --threads ${task.cpus} ${args} ${fasta} ${meta.id}/${meta.id}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: \$( bowtie2 --version 2>&1 | sed -n "1s/.*version //p" )
    END_VERSIONS
    """

    stub:
    """
    mkdir -p ${meta.id}
    touch ${meta.id}/${meta.id}.1.bt2

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        bowtie2: stub
    END_VERSIONS
    """
}

process FASTQ_SCREEN {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(reads)
    val genomes
    path indexes, stageAs: 'indexes/*'

    output:
    tuple val(meta), path("*_screen.txt"), emit: txt
    tuple val(meta), path("*_screen.html"), emit: html
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def read = reads instanceof List ? reads[0] : reads
    def conf = genomes.collect { g -> "DATABASE\\t${g[0]}\\tindexes/${g[1]}/${g[2]}" }.join('\\n')
    """
    printf 'BOWTIE2\\t%s\\n${conf}\\n' "\$(command -v bowtie2)" > fastq_screen.conf
    fastq_screen \\
        --conf fastq_screen.conf \\
        --aligner bowtie2 \\
        --threads ${task.cpus} \\
        --outdir . \\
        ${args} \\
        ${read}
    for f in *_screen.txt *_screen.html; do
        case "\$f" in ${meta.id}*) ;; *) mv "\$f" "${meta.id}_\${f#*_}" ;; esac
    done

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastq_screen: \$( fastq_screen --version | sed -e "s/FastQ Screen v//g" )
        bowtie2: \$( bowtie2 --version 2>&1 | sed -n "1s/.*version //p" )
    END_VERSIONS
    """

    stub:
    """
    touch ${meta.id}_screen.txt ${meta.id}_screen.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        fastq_screen: stub
    END_VERSIONS
    """
}
