include { ENTREZ_DIRECT_RUNINFO  } from '../../modules/entrez_direct/main'
include { CURL_BIOSTUDIES        } from '../../modules/curl/main'
include { CURL_ENAFILEREPORT     } from '../../modules/curl/main'
include { CURL_ENAFASTQ          } from '../../modules/curl/main'
include { CURL_ZENODORECORD      } from '../../modules/curl/main'
include { CURL_ZENODOFILE        } from '../../modules/curl/main'
include { SRATOOLKIT_SRASTAT     } from '../../modules/sratoolkit/main'
include { SRATOOLKIT_FASTERQDUMP } from '../../modules/sratoolkit/main'
include { SEQKIT_STATS           } from '../../modules/seqkit/main'

workflow DOWNLOAD {
    take:
    queries

    main:
    def sources = ['auto', 'ena', 'sra']
    if (!(params.download_source in sources)) {
        error("Unknown --download_source '${params.download_source}', expected one of ${sources}")
    }

    typed = queries.branch { q ->
        zenodo: q =~ /(?i)zenodo/
        biostudies: q ==~ /E-[A-Z]{4}-\d+/
        ena: q ==~ /(PRJ[A-Z]{2}\d+|[ESD]R[RXSPA]\d+|SAM[A-Z]{0,2}\d+)/
        ncbi: true
    }

    CURL_BIOSTUDIES(typed.biostudies)
    ena_queries = typed.ena.mix(
        CURL_BIOSTUDIES.out.ena.flatMap { _query, f -> f.readLines()*.trim().findAll { l -> l } }
    )

    CURL_ENAFILEREPORT(ena_queries)
    ENTREZ_DIRECT_RUNINFO(typed.ncbi)
    runinfo = CURL_ENAFILEREPORT.out.runinfo.mix(ENTREZ_DIRECT_RUNINFO.out.runinfo)

    runs = runinfo
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

    sra_runs = channel.empty()
    ena_reads = channel.empty()
    if (params.download_source == 'sra') {
        sra_runs = runs
    }
    else {
        CURL_ENAFASTQ(runs)
        ena_reads = CURL_ENAFASTQ.out.reads.map { meta, files -> [meta + [source: 'curl_enafastq'], files] }
        sra_runs = CURL_ENAFASTQ.out.missing.map { meta, _flag -> meta }
    }

    SRATOOLKIT_SRASTAT(sra_runs)
    SRATOOLKIT_FASTERQDUMP(sra_runs)
    sra_reads = SRATOOLKIT_FASTERQDUMP.out.reads.map { meta, files -> [meta + [source: 'sratoolkit_fasterqdump'], files] }

    zenodo_records = typed.zenodo.map { q ->
        def m = q =~ /(\d+)\D*$/
        if (!m.find()) {
            error("Cannot find a Zenodo record id in '${q}'")
        }
        m.group(1)
    }
    CURL_ZENODORECORD(zenodo_records)
    zenodo_files = CURL_ZENODORECORD.out.files
        .splitCsv(sep: '\t')
        .map { row -> [record: row[0], name: row[1], size: row[2], md5: row[3], url: row[4]] }
    CURL_ZENODOFILE(zenodo_files)
    zenodo_reads = CURL_ZENODOFILE.out.file
        .map { file_meta, f ->
            def m = file_meta.name =~ params.zenodo_mate_regex
            def sample = m.matches() ? m.group(1) : file_meta.name.replaceAll(/\.(fastq|fq)\.gz$/, '')
            [sample, file_meta.record, f]
        }
        .groupTuple()
        .map { sample, records, files ->
            def fq = files.sort { f -> f.name }
            [[id: sample, single_end: fq.size() == 1, experiment: '', sample_name: sample, organism: '', source: 'curl_zenodofile', record: records[0]], fq]
        }

    reads = ena_reads.mix(sra_reads).mix(zenodo_reads).map { meta, files ->
        def fq = files instanceof List ? files.sort { f -> f.name } : [files]
        if (fq.size() > 2) {
            error("${meta.id}: expected 1 or 2 FASTQ files, got ${fq*.name}")
        }
        [meta + [single_end: fq.size() == 1], fq]
    }

    SEQKIT_STATS(reads)

    published = file(params.outdir).toAbsolutePath()
    reads
        .map { meta, fq ->
            def paths = fq.collect { f -> "${published}/${meta.source}/${f.name}" }
            [meta.id, paths[0], paths.size() == 2 ? paths[1] : '', '', '', meta.single_end, meta.experiment, meta.sample_name, meta.organism, meta.source].join(',')
        }
        .collectFile(
            name: 'samplesheet.csv',
            storeDir: "${params.outdir}/download",
            seed: 'sample,fastq_1,fastq_2,bam,bai,single_end,experiment,sample_name,organism,source',
            newLine: true,
            sort: true,
        )

    runinfo.collectFile(name: 'runinfo.csv', storeDir: "${params.outdir}/download", keepHeader: true, skip: 1)

    emit:
    reads    = reads
    stats    = SEQKIT_STATS.out.stats
    versions = ENTREZ_DIRECT_RUNINFO.out.versions
        .mix(CURL_ENAFILEREPORT.out.versions)
        .mix(SRATOOLKIT_FASTERQDUMP.out.versions)
        .mix(CURL_ZENODOFILE.out.versions)
        .mix(SEQKIT_STATS.out.versions)
}
