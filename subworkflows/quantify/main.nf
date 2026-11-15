include { SALMON_QUANT             } from '../../modules/salmon/main'
include { RSEM_CALCULATEEXPRESSION } from '../../modules/rsem/main'
include { SUBREAD_FEATURECOUNTS    } from '../../modules/subread/main'
include { TXIMPORT_TX2GENE         } from '../../modules/tximport/main'
include { TXIMPORT_MERGE           } from '../../modules/tximport/main'

workflow QUANTIFY {
    take:
    transcriptome_bam
    rsem_index
    gtf
    run_salmon
    run_rsem

    main:
    versions = channel.empty()
    multiqc_files = channel.empty()
    merged = channel.empty()
    script = file("${projectDir}/modules/tximport/tximport_merge.R", checkIfExists: true)

    tx2gene = channel.empty()
    if (run_salmon || run_rsem) {
        TXIMPORT_TX2GENE(gtf.map { genome, anno -> [[id: genome, genome: genome], anno] })
        tx2gene = TXIMPORT_TX2GENE.out.tx2gene.map { meta, f -> [meta.genome, f] }
        versions = versions.mix(TXIMPORT_TX2GENE.out.versions)
    }

    keyed = transcriptome_bam
        .map { meta, bam -> [meta.genome, meta, bam] }
        .combine(rsem_index, by: 0)

    if (run_salmon) {
        SALMON_QUANT(
            keyed
                .combine(gtf, by: 0)
                .map { _genome, meta, bam, _index, fasta, anno -> [meta, bam, fasta, anno] }
        )
        multiqc_files = multiqc_files.mix(SALMON_QUANT.out.results.map { _meta, dir -> dir })
        versions = versions.mix(SALMON_QUANT.out.versions)
        merged = merged.mix(SALMON_QUANT.out.results.map { meta, dir -> [meta.genome, 'salmon', meta.id, dir] })
    }

    if (run_rsem) {
        RSEM_CALCULATEEXPRESSION(keyed.map { _genome, meta, bam, index, _fasta -> [meta, bam, index] })
        multiqc_files = multiqc_files.mix(RSEM_CALCULATEEXPRESSION.out.stat.map { _meta, dir -> dir })
        versions = versions.mix(RSEM_CALCULATEEXPRESSION.out.versions)
        merged = merged.mix(RSEM_CALCULATEEXPRESSION.out.isoforms.map { meta, f -> [meta.genome, 'rsem', meta.id, f] })
    }

    TXIMPORT_MERGE(
        merged
            .map { genome, quantifier, sample, quant -> [[genome, quantifier], [sample, quant]] }
            .groupTuple()
            .map { key, entries -> [key[0], key[1], entries.sort { a, b -> a[0] <=> b[0] }] }
            .combine(tx2gene, by: 0)
            .map { genome, quantifier, entries, t2g ->
                [[id: quantifier, genome: genome, quantifier: quantifier], entries.collect { e -> e[0] }, entries.collect { e -> e[1] }, t2g, script]
            }
    )
    versions = versions.mix(TXIMPORT_MERGE.out.versions)

    emit:
    tables        = TXIMPORT_MERGE.out.tables
    multiqc_files = multiqc_files
    versions      = versions
}

workflow FEATURE_COUNTS {
    take:
    bam_bai
    gtf
    introns

    main:
    cohorts = bam_bai
        .map { meta, bam, _bai -> [meta.genome, meta, bam] }
        .groupTuple()
        .map { genome, metas, bams ->
            def libs = metas.collect { m -> [m.single_end, m.strandedness] }.unique()
            if (libs.size() != 1) {
                error("featureCounts needs one library layout and strandedness per genome; ${genome} has ${libs}")
            }
            [genome, [genome: genome, single_end: libs[0][0], strandedness: libs[0][1]], bams.sort { b -> b.name }]
        }

    genome_keys = cohorts.map { c -> c[0] }

    gene = gtf.map { genome, anno -> [genome, [id: 'gene', args: params.gene_count_args], anno] }
    intron = introns.map { genome, saf -> [genome, [id: 'intron', args: params.intron_count_args], saf] }

    regions = params.regions
        ? channel.fromPath(params.regions, checkIfExists: true)
            .splitCsv(header: true)
            .map { row ->
                def args = [
                    row.feature ? "-t ${row.feature}" : '',
                    row.attribute ? "-g ${row.attribute}" : '',
                    row.args ?: '',
                ].join(' ').trim()
                [row.genome ?: '', [id: row.name, args: args], file(row.file, checkIfExists: true)]
            }
            .combine(genome_keys)
            .filter { target, _meta, _anno, genome -> !params.genomes || !target || target == genome }
            .map { _target, meta, anno, genome -> [genome, meta, anno] }
        : channel.empty()

    SUBREAD_FEATURECOUNTS(
        gene.mix(intron).mix(regions)
            .combine(cohorts, by: 0)
            .map { _genome, anno_meta, anno, lib, bams -> [anno_meta + lib, anno, bams] }
    )

    emit:
    counts        = SUBREAD_FEATURECOUNTS.out.counts
    multiqc_files = SUBREAD_FEATURECOUNTS.out.summary.filter { meta, _f -> meta.id == 'gene' }.map { _meta, f -> f }
    versions      = SUBREAD_FEATURECOUNTS.out.versions
}
