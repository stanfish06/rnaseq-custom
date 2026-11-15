include { QC_FASTQ       } from '../../subworkflows/qc/main'
include { QC_BAM         } from '../../subworkflows/qc/main'
include { PREPARE_GENOME } from '../../subworkflows/prepare_genome/main'
include { ALIGN          } from '../../subworkflows/align/main'
include { QUANTIFY       } from '../../subworkflows/quantify/main'
include { FEATURE_COUNTS } from '../../subworkflows/quantify/main'
include { ISOFORM        } from '../../subworkflows/isoform/main'
include { CONTAMINATION  } from '../../subworkflows/contamination/main'
include { UMICOLLAPSE    } from '../../modules/umicollapse/main'
include { MULTIQC        } from '../../modules/multiqc/main'

workflow RNASEQ {
    take:
    reads
    genomes
    tag3p

    main:
    quantifiers = tag3p ? [] : params.quantifiers.tokenize(',')
    isoform_tools = (tag3p || !params.isoform) ? [] : params.isoform.tokenize(',')
    need_rsem = 'rsem' in quantifiers || 'salmon' in quantifiers

    QC_FASTQ(reads)
    PREPARE_GENOME(genomes, need_rsem, params.count_introns, false)
    gtf = PREPARE_GENOME.out.gtf
    ALIGN(QC_FASTQ.out.reads, PREPARE_GENOME.out.star_index, gtf)

    multiqc_files = QC_FASTQ.out.multiqc_files.mix(ALIGN.out.multiqc_files)
    versions = QC_FASTQ.out.versions
        .mix(PREPARE_GENOME.out.versions)
        .mix(ALIGN.out.versions)

    bam_bai = ALIGN.out.bam_bai
    if (tag3p) {
        UMICOLLAPSE(ALIGN.out.bam_bai)
        bam_bai = UMICOLLAPSE.out.bam_bai
        versions = versions.mix(UMICOLLAPSE.out.versions)
    }

    QUANTIFY(
        ALIGN.out.transcriptome_bam,
        PREPARE_GENOME.out.rsem_index,
        gtf,
        'salmon' in quantifiers,
        'rsem' in quantifiers,
    )
    multiqc_files = multiqc_files.mix(QUANTIFY.out.multiqc_files)
    versions = versions.mix(QUANTIFY.out.versions)

    if (tag3p || 'featurecounts' in quantifiers) {
        FEATURE_COUNTS(bam_bai, gtf, PREPARE_GENOME.out.introns)
        multiqc_files = multiqc_files.mix(FEATURE_COUNTS.out.multiqc_files)
        versions = versions.mix(FEATURE_COUNTS.out.versions)
    }

    if (isoform_tools) {
        ISOFORM(bam_bai, gtf, isoform_tools)
        versions = versions.mix(ISOFORM.out.versions)
    }

    if (params.contaminants) {
        CONTAMINATION(QC_FASTQ.out.reads)
        multiqc_files = multiqc_files.mix(CONTAMINATION.out.multiqc_files)
        versions = versions.mix(CONTAMINATION.out.versions)
    }

    if (!params.skip_rustqc) {
        QC_BAM(bam_bai, gtf)
        multiqc_files = multiqc_files.mix(QC_BAM.out.multiqc_files)
        versions = versions.mix(QC_BAM.out.versions)
    }

    MULTIQC(multiqc_files.collect())

    emit:
    bam_bai  = bam_bai
    versions = versions
}
