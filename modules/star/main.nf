process STAR {
    tag "${meta.id}"
    label 'process_octa'

    input:
    tuple val(meta), path(reads)

    output:
    tmp.txt

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    star \\
        --runTreadN \\
        --runMode \\
        --genomeDir \\
        --genomeFastaFiles \\
        --sjdbGTFfile \\
        --sjdbOverhang \\
}
