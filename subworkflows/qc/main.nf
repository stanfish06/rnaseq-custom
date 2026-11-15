include { FASTQC     } from '../../modules/fastqc/main'
include { FASTP      } from '../../modules/fastp/main'
include { RUSTQC_RNA } from '../../modules/rustqc/main'

workflow QC_FASTQ {
    take:
    reads

    main:
    FASTQC(reads)
    FASTP(reads)

    multiqc_files = channel.empty()
        .mix(FASTQC.out.zip.map { _meta, zip -> zip })
        .mix(FASTP.out.json.map { _meta, json -> json })

    versions = channel.empty()
        .mix(FASTQC.out.versions)
        .mix(FASTP.out.versions)

    emit:
    reads         = FASTP.out.reads
    multiqc_files = multiqc_files
    versions      = versions
}

workflow QC_BAM {
    take:
    bam
    gtf

    main:
    RUSTQC_RNA(
        bam
            .map { meta, b, bai -> [meta.genome, meta, b, bai] }
            .combine(gtf, by: 0)
            .map { _genome, meta, b, bai, anno -> [meta, b, bai, anno] }
    )

    multiqc_files = RUSTQC_RNA.out.results.map { _meta, dir -> dir }

    emit:
    multiqc_files = multiqc_files
    versions      = RUSTQC_RNA.out.versions
}
