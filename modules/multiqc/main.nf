process MULTIQC {
    label 'process_mono'

    input:
    path multiqc_files, stageAs: "?/*"

    output:
    path "*multiqc_report.html", emit: report
    path "*_data", emit: data
    path "*_plots", emit: plots, optional: true
    path "versions.yml", emit: versions

    script:
    def args = task.ext.args ?: ''
    def prefix = task.ext.prefix ? "--filename ${task.ext.prefix}.html" : ''
    """
    multiqc \\
        --force \\
        ${args} \\
        ${prefix} \\
        .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """

    stub:
    """
    mkdir multiqc_data
    touch multiqc_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: stub
    END_VERSIONS
    """
}
