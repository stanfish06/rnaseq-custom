include { QC_FASTQ } from './subworkflows/qc/main'
include { QC_BAM   } from './subworkflows/qc/main'
include { MULTIQC  } from './modules/multiqc/main'

workflow {
    rows = channel.fromPath(params.input, checkIfExists: true)
        .splitCsv(header: true)

    reads = rows
        .filter { row -> row.fastq_1 }
        .map { row ->
            def single_end = !row.fastq_2
            def meta = [id: row.sample, single_end: single_end]
            def files = single_end
                ? [file(row.fastq_1, checkIfExists: true)]
                : [file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true)]
            [meta, files]
        }

    bams = rows
        .filter { row -> row.bam }
        .map { row ->
            def meta = [id: row.sample, single_end: row.single_end == 'true']
            def bai = row.bai ? file(row.bai, checkIfExists: true) : []
            [meta, file(row.bam, checkIfExists: true), bai]
        }

    gtf = params.gtf ? file(params.gtf, checkIfExists: true) : []

    QC_FASTQ(reads)
    QC_BAM(bams, gtf)

    multiqc_files = QC_FASTQ.out.multiqc_files
        .mix(QC_BAM.out.multiqc_files)
        .collect()

    MULTIQC(multiqc_files)
}
