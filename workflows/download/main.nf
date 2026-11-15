include { ENTREZ_DIRECT_RUNINFO  } from '../../modules/entrez_direct/main'
include { SRATOOLKIT_SRASTAT     } from '../../modules/sratoolkit/main'
include { SRATOOLKIT_FASTERQDUMP } from '../../modules/sratoolkit/main'
include { SEQKIT_STATS           } from '../../modules/seqkit/main'

workflow DOWNLOAD {
    take:
    queries

    main:
    ENTREZ_DIRECT_RUNINFO(queries)

    runs = ENTREZ_DIRECT_RUNINFO.out.runinfo
        .splitCsv(header: true)
        .filter { row -> row.Run ==~ /[SED]RR\d+/ }
        .unique { row -> row.Run }
        .map { row ->
            [
                id: row.Run,
                single_end: row.LibraryLayout != 'PAIRED',
                experiment: row.Experiment,
                sample_name: row.SampleName,
                organism: row.ScientificName,
                spots: row.spots,
                bases: row.bases,
            ]
        }

    SRATOOLKIT_SRASTAT(runs)
    SRATOOLKIT_FASTERQDUMP(runs)
    SEQKIT_STATS(SRATOOLKIT_FASTERQDUMP.out.reads)

    reads = SRATOOLKIT_FASTERQDUMP.out.reads.map { meta, files ->
        def fq = files instanceof List ? files.sort { f -> f.name } : [files]
        def paired = fq.size() == 2
        [meta + [single_end: !paired], fq]
    }

    published = file(params.outdir).toAbsolutePath()
    reads
        .map { meta, fq ->
            def paths = fq.collect { f -> "${published}/sratoolkit_fasterqdump/${f.name}" }
            [meta.id, paths[0], paths.size() == 2 ? paths[1] : '', '', '', meta.single_end, meta.experiment, meta.sample_name, meta.organism].join(',')
        }
        .collectFile(
            name: 'samplesheet.csv',
            storeDir: "${params.outdir}/download",
            seed: 'sample,fastq_1,fastq_2,bam,bai,single_end,experiment,sample_name,organism',
            newLine: true,
            sort: true,
        )

    ENTREZ_DIRECT_RUNINFO.out.runinfo
        .collectFile(name: 'runinfo.csv', storeDir: "${params.outdir}/download", keepHeader: true, skip: 1)

    emit:
    reads    = reads
    stats    = SEQKIT_STATS.out.stats
    versions = ENTREZ_DIRECT_RUNINFO.out.versions
        .mix(SRATOOLKIT_SRASTAT.out.versions)
        .mix(SRATOOLKIT_FASTERQDUMP.out.versions)
        .mix(SEQKIT_STATS.out.versions)
}
