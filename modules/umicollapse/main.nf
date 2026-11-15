process UMICOLLAPSE {
    tag "${meta.id}"
    label 'process_quad'

    input:
    tuple val(meta), path(bam), path(bai)

    output:
    tuple val(meta), path("*.dedup.bam"), path("*.dedup.bam.bai"), emit: bam_bai
    tuple val(meta), path("*.umicollapse.log"), emit: log
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ?: "${meta.id}"
    def heap = Math.max(1, (task.memory.toGiga() * 0.8).intValue())
    """
    export UMICOLLAPSE_JAVA_OPTS="-Xms1g -Xmx${heap}g -Xss1G -XX:+ExitOnOutOfMemoryError -Djava.io.tmpdir=\$PWD"
    umicollapse bam \\
        -i ${bam} \\
        -o ${prefix}.dedup.bam \\
        ${args} \\
        > ${prefix}.umicollapse.log
    samtools index -@ ${task.cpus} ${prefix}.dedup.bam

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umicollapse: 1.1.0
        samtools: \$( samtools --version | sed -n "1s/samtools //p" )
    END_VERSIONS
    """

    stub:
    def prefix = task.ext.prefix ?: "${meta.id}"
    """
    touch ${prefix}.dedup.bam ${prefix}.dedup.bam.bai ${prefix}.umicollapse.log

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        umicollapse: stub
    END_VERSIONS
    """
}
