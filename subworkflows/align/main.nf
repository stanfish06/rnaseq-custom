include { STAR_ALIGN        } from '../../modules/star/main'
include { SAMTOOLS_INDEX    } from '../../modules/samtools/main'
include { SAMTOOLS_FLAGSTAT } from '../../modules/samtools/main'

workflow ALIGN {
    take:
    reads
    star_index
    gtf

    main:
    STAR_ALIGN(
        reads
            .map { meta, fq -> [meta.genome, meta, fq] }
            .combine(star_index, by: 0)
            .combine(gtf, by: 0)
            .map { _genome, meta, fq, index, anno -> [meta, fq, index, anno] }
    )
    SAMTOOLS_INDEX(STAR_ALIGN.out.bam)
    SAMTOOLS_FLAGSTAT(SAMTOOLS_INDEX.out.bam_bai)

    multiqc_files = channel.empty()
        .mix(STAR_ALIGN.out.log_final.map { _meta, f -> f })
        .mix(SAMTOOLS_FLAGSTAT.out.flagstat.map { _meta, f -> f })

    versions = channel.empty()
        .mix(STAR_ALIGN.out.versions)
        .mix(SAMTOOLS_INDEX.out.versions)
        .mix(SAMTOOLS_FLAGSTAT.out.versions)

    emit:
    bam_bai           = SAMTOOLS_INDEX.out.bam_bai
    transcriptome_bam = STAR_ALIGN.out.transcriptome_bam
    gene_counts       = STAR_ALIGN.out.gene_counts
    multiqc_files     = multiqc_files
    versions          = versions
}
