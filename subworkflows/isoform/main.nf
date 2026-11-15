include { STRINGTIE_ASSEMBLE  } from '../../modules/stringtie/main'
include { STRINGTIE_MERGE     } from '../../modules/stringtie/main'
include { STRINGTIE_QUANT     } from '../../modules/stringtie/main'
include { BALLGOWN            } from '../../modules/ballgown/main'
include { CUFFLINKS_CUFFQUANT } from '../../modules/cufflinks/main'
include { CUFFLINKS_CUFFDIFF  } from '../../modules/cufflinks/main'

workflow ISOFORM {
    take:
    bam_bai
    gtf
    tools

    main:
    versions = channel.empty()
    results = channel.empty()

    with_gtf = bam_bai
        .map { meta, bam, bai -> [meta.genome, meta, bam, bai] }
        .combine(gtf, by: 0)

    cohorts = bam_bai
        .map { meta, _bam, _bai -> [meta.genome, meta] }
        .groupTuple()
        .map { genome, metas -> [genome, metas.sort { a, b -> a.id <=> b.id }] }

    if ('stringtie' in tools || 'ballgown' in tools) {
        STRINGTIE_ASSEMBLE(with_gtf.map { _genome, meta, bam, bai, anno -> [meta, bam, bai, anno] })
        STRINGTIE_MERGE(
            STRINGTIE_ASSEMBLE.out.gtf
                .map { meta, f -> [meta.genome, f] }
                .groupTuple()
                .combine(gtf, by: 0)
                .map { genome, files, anno -> [[id: genome, genome: genome], files, anno] }
        )
        merged = STRINGTIE_MERGE.out.gtf.map { meta, f -> [meta.genome, f] }
        STRINGTIE_QUANT(
            bam_bai
                .map { meta, bam, bai -> [meta.genome, meta, bam, bai] }
                .combine(merged, by: 0)
                .map { _genome, meta, bam, bai, anno -> [meta, bam, bai, anno] }
        )
        versions = versions
            .mix(STRINGTIE_ASSEMBLE.out.versions)
            .mix(STRINGTIE_MERGE.out.versions)
            .mix(STRINGTIE_QUANT.out.versions)

        if ('ballgown' in tools) {
            BALLGOWN(
                STRINGTIE_QUANT.out.ballgown
                    .map { meta, dir -> [meta.genome, dir] }
                    .groupTuple()
                    .combine(cohorts, by: 0)
                    .map { genome, dirs, metas ->
                        [[id: genome, genome: genome], dirs, ['sample,condition'] + metas.collect { m -> "${m.id},${m.condition}" }]
                    }
            )
            results = results.mix(BALLGOWN.out.tables.map { _meta, f -> f }.flatten())
            versions = versions.mix(BALLGOWN.out.versions)
        }
    }

    if ('cufflinks' in tools) {
        CUFFLINKS_CUFFQUANT(with_gtf.map { _genome, meta, bam, bai, anno -> [meta, bam, bai, anno] })
        CUFFLINKS_CUFFDIFF(
            CUFFLINKS_CUFFQUANT.out.cxb
                .map { meta, f -> [meta.genome, f] }
                .groupTuple()
                .combine(cohorts, by: 0)
                .combine(gtf, by: 0)
                .filter { genome, _cxbs, metas, _anno ->
                    if (metas.size() < 2) {
                        log.warn("Skipping cuffdiff/cuffnorm for genome ${genome}: needs at least 2 samples, has ${metas.size()}")
                    }
                    metas.size() >= 2
                }
                .map { genome, cxbs, metas, anno ->
                    def by_condition = metas.groupBy { m -> m.condition }
                    def labels = by_condition.keySet().toList().sort()
                    def groups = labels.collect { l -> by_condition[l].collect { m -> m.id }.join(',') }
                    def library_type = [forward: 'fr-secondstrand', reverse: 'fr-firststrand'][metas[0].strandedness] ?: 'fr-unstranded'
                    [[id: genome, genome: genome], cxbs, labels, groups, library_type, anno]
                }
        )
        results = results.mix(CUFFLINKS_CUFFDIFF.out.results.map { _meta, d -> d })
        versions = versions
            .mix(CUFFLINKS_CUFFQUANT.out.versions)
            .mix(CUFFLINKS_CUFFDIFF.out.versions)
    }

    emit:
    results  = results
    versions = versions
}
