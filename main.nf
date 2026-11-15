include { QC_FASTQ } from './subworkflows/qc/main'
include { QC_BAM   } from './subworkflows/qc/main'
include { MULTIQC  } from './modules/multiqc/main'
include { RNASEQ   } from './workflows/rnaseq/main'
include { SLAMSEQ  } from './workflows/slamseq/main'
include { DOWNLOAD } from './workflows/download/main'

def genomeEntry(name, fasta, gtf, star_index, rsem_index, gedi_index) {
    if (!fasta || !gtf) {
        error("Genome '${name}' needs both fasta and gtf")
    }
    return [
        id: name,
        fasta: file(fasta, checkIfExists: true),
        gtf: file(gtf, checkIfExists: true),
        star_index: star_index ? file(star_index, checkIfExists: true) : null,
        rsem_index: rsem_index ? file(rsem_index, checkIfExists: true) : null,
        gedi_index: gedi_index ? file(gedi_index, checkIfExists: true) : null,
    ]
}

workflow {
    main:
    def modes = ['qc', 'standard', 'tag3p', 'slamseq', 'download']
    if (!(params.mode in modes)) {
        error("Unknown --mode '${params.mode}', expected one of ${modes}")
    }
    if (!params.input) {
        error("--input is required")
    }
    def presets = ['default', 'encode_standard']
    if (!(params.star_preset in presets)) {
        error("Unknown --star_preset '${params.star_preset}', expected one of ${presets}")
    }
    if (params.star_preset == 'encode_standard' && params.mode != 'standard') {
        log.warn("--star_preset encode_standard only applies to --mode standard; using ${params.mode} STAR settings")
    }

    if (params.mode == 'download') {
        queries = channel.fromPath(params.input, checkIfExists: true)
            .splitText()
            .map { line -> line.trim() }
            .filter { line -> line && !line.startsWith('#') }
        DOWNLOAD(queries)
    }
    else {
        def default_strand = params.strandedness ?: (params.mode == 'tag3p' ? 'forward' : 'unstranded')
        rows = channel.fromPath(params.input, checkIfExists: true)
            .splitCsv(header: true)

        reads = rows
            .filter { row -> row.fastq_1 }
            .map { row ->
                def single_end = !row.fastq_2
                if (row.genome && !params.genomes) {
                    error("Sample ${row.sample} sets genome '${row.genome}' but --genomes is not given")
                }
                if (params.genomes && !row.genome) {
                    error("Sample ${row.sample} has no genome; --genomes needs a genome column in the samplesheet")
                }
                def meta = [
                    id: row.sample,
                    single_end: single_end,
                    strandedness: row.strandedness ?: default_strand,
                    condition: row.condition ?: row.sample,
                    genome: params.genomes ? row.genome : 'genome',
                ]
                def files = single_end
                    ? [file(row.fastq_1, checkIfExists: true)]
                    : [file(row.fastq_1, checkIfExists: true), file(row.fastq_2, checkIfExists: true)]
                [meta, files]
            }

        if (params.mode == 'qc') {
            bams = rows
                .filter { row -> row.bam }
                .map { row ->
                    def meta = [id: row.sample, single_end: row.single_end == 'true', genome: 'genome']
                    def bai = row.bai ? file(row.bai, checkIfExists: true) : []
                    [meta, file(row.bam, checkIfExists: true), bai]
                }

            gtf = channel.of(['genome', params.gtf ? file(params.gtf, checkIfExists: true) : []])

            QC_FASTQ(reads)
            QC_BAM(bams, gtf)

            multiqc_files = QC_FASTQ.out.multiqc_files
                .mix(QC_BAM.out.multiqc_files)
                .collect()

            MULTIQC(multiqc_files)
        }
        else {
            if (params.genomes) {
                genome_rows = channel.fromPath(params.genomes, checkIfExists: true)
                    .splitCsv(header: true)
                    .map { row -> genomeEntry(row.name, row.fasta, row.gtf, row.star_index, row.rsem_index, row.gedi_index) }
                known = genome_rows.map { g -> g.id }.toList().map { names -> [names] }
                used = reads
                    .map { meta, _fq -> meta.genome }
                    .unique()
                    .combine(known)
                    .map { name, names ->
                        if (!(name in names)) {
                            error("Genome '${name}' is not listed in ${params.genomes}")
                        }
                        [name]
                    }
                genomes = genome_rows
                    .map { g -> [g.id, g] }
                    .join(used)
                    .map { _name, g -> g }
            }
            else {
                genomes = channel.of(genomeEntry('genome', params.fasta, params.gtf, params.star_index, params.rsem_index, params.gedi_index))
            }

            if (params.mode == 'slamseq') {
                SLAMSEQ(reads, genomes)
            }
            else {
                RNASEQ(reads, genomes, params.mode == 'tag3p')
            }
        }
    }
}
