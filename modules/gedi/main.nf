process GEDI_INDEXGENOME {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(fasta), path(gtf)

    output:
    tuple val(meta), path("gedi"), emit: index
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def name = meta.id
    def mem = Math.max(2, (task.memory.toGiga() * 0.8).intValue())
    """
    export JAVA_TOOL_OPTIONS="-Duser.home=\$HOME"
    mkdir -p gedi
    cp -L ${fasta} gedi/${name}.fa
    cp -L ${gtf} gedi/${name}.gtf
    gedi -mem ${mem}G -e IndexGenome \\
        -s gedi/${name}.fa \\
        -a gedi/${name}.gtf \\
        -n ${name} \\
        -o gedi/${name}.oml \\
        -f gedi \\
        -nostar -nobowtie -nokallisto \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gedi: 1.0.6a
    END_VERSIONS
    """

    stub:
    """
    mkdir -p gedi
    touch gedi/${meta.id}.oml

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gedi: stub
    END_VERSIONS
    """
}

process GEDI_SLAM {
    tag "${meta.id}"
    label 'process_octa'

    input:
    tuple val(meta), val(ids), path(bams, stageAs: 'input/*'), path(bais, stageAs: 'input/*'), path(index)

    output:
    tuple val(meta), path("slam/*"), emit: results
    tuple val(meta), path("*.bamlist.cit"), emit: cit
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = params.slam_prefix
    def no4su = params.no4su_pattern ? "-no4sUpattern '${params.no4su_pattern}'" : ''
    def mem = Math.max(2, (task.memory.toGiga() * 0.8).intValue())
    def bam_list = bams instanceof List ? bams : [bams]
    def bai_list = bais instanceof List ? bais : [bais]
    def links = [ids, bam_list, bai_list].transpose().collect { row -> "ln -s ${row[1]} ${row[0]}.bam && ln -s ${row[2]} ${row[0]}.bam.bai" }.join('\n    ')
    """
    export JAVA_TOOL_OPTIONS="-Duser.home=\$HOME"
    mkdir -p genome
    name=\$(basename "\$(ls ${index}/*.oml | head -n 1)" .oml)
    build_dir=\$(head -n 1 ${index}/\$name.fi | sed 's#/[^/]*\$##')
    for f in ${index}/*; do
        case "\$f" in
            *.oml|*.fi) sed "s#\$build_dir/#\$PWD/genome/#g" "\$f" > genome/\$(basename "\$f") ;;
            *) ln -s "\$(readlink -f "\$f")" genome/ ;;
        esac
    done
    ${links}
    ls *.bam > ${prefix}.bamlist
    bamlist2cit -n ${task.cpus} ${prefix}.bamlist
    test -s ${prefix}.bamlist.cit

    mkdir -p slam
    gedi -mem ${mem}G -e Slam \\
        -genomic genome/\$name.oml \\
        -reads ${prefix}.bamlist.cit \\
        -prefix slam/${prefix} \\
        -nthreads ${task.cpus} \\
        ${no4su} \\
        ${args}

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gedi: 1.0.6a
    END_VERSIONS
    """

    stub:
    def prefix = params.slam_prefix
    """
    mkdir -p slam
    touch slam/${prefix}.tsv.gz ${prefix}.bamlist.cit

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        gedi: stub
    END_VERSIONS
    """
}
