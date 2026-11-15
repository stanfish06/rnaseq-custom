include { QC_FASTQ       } from '../../subworkflows/qc/main'
include { PREPARE_GENOME } from '../../subworkflows/prepare_genome/main'
include { ALIGN          } from '../../subworkflows/align/main'
include { FEATURE_COUNTS } from '../../subworkflows/quantify/main'
include { CONTAMINATION  } from '../../subworkflows/contamination/main'
include { GEDI_SLAM      } from '../../modules/gedi/main'
include { MULTIQC        } from '../../modules/multiqc/main'

workflow SLAMSEQ {
    take:
    reads
    genomes

    main:
    QC_FASTQ(reads)
    PREPARE_GENOME(genomes, false, params.count_introns, true)
    gtf = PREPARE_GENOME.out.gtf
    ALIGN(QC_FASTQ.out.reads, PREPARE_GENOME.out.star_index, gtf)

    GEDI_SLAM(
        ALIGN.out.bam_bai
            .map { meta, bam, bai -> [meta.genome, [meta.id, bam, bai]] }
            .groupTuple()
            .combine(PREPARE_GENOME.out.gedi_index, by: 0)
            .map { genome, samples, index ->
                def sorted = samples.sort { a, b -> a[0] <=> b[0] }
                [[id: genome, genome: genome], sorted.collect { s -> s[0] }, sorted.collect { s -> s[1] }, sorted.collect { s -> s[2] }, index]
            }
    )

    multiqc_files = QC_FASTQ.out.multiqc_files.mix(ALIGN.out.multiqc_files)
    versions = QC_FASTQ.out.versions
        .mix(PREPARE_GENOME.out.versions)
        .mix(ALIGN.out.versions)
        .mix(GEDI_SLAM.out.versions)

    if (params.quantifiers.tokenize(',').contains('featurecounts')) {
        FEATURE_COUNTS(ALIGN.out.bam_bai, gtf, PREPARE_GENOME.out.introns)
        multiqc_files = multiqc_files.mix(FEATURE_COUNTS.out.multiqc_files)
        versions = versions.mix(FEATURE_COUNTS.out.versions)
    }

    if (params.contaminants) {
        CONTAMINATION(QC_FASTQ.out.reads)
        multiqc_files = multiqc_files.mix(CONTAMINATION.out.multiqc_files)
        versions = versions.mix(CONTAMINATION.out.versions)
    }

    MULTIQC(multiqc_files.collect())

    emit:
    results  = GEDI_SLAM.out.results
    versions = versions
}
