include { FASTQ_SCREEN_INDEX } from '../../modules/fastq_screen/main'
include { FASTQ_SCREEN       } from '../../modules/fastq_screen/main'

workflow CONTAMINATION {
    take:
    reads

    main:
    genomes = channel.fromPath(params.contaminants, checkIfExists: true)
        .splitCsv(header: true)
        .branch { row ->
            prebuilt: row.bowtie2_index
            build: true
        }

    FASTQ_SCREEN_INDEX(
        genomes.build.map { row -> [[id: row.name], file(row.fasta, checkIfExists: true)] }
    )

    prebuilt = genomes.prebuilt.map { row ->
        def prefix = file(row.bowtie2_index)
        [row.name, prefix.parent, prefix.name]
    }
    built = FASTQ_SCREEN_INDEX.out.index.map { meta, dir -> [meta.id, dir, meta.id] }

    panel = built.mix(prebuilt)
        .toSortedList { a, b -> a[0] <=> b[0] }

    FASTQ_SCREEN(
        reads,
        panel.map { entries -> entries.collect { e -> [e[0], e[1].name, e[2]] } },
        panel.map { entries -> entries.collect { e -> e[1] } },
    )

    emit:
    multiqc_files = FASTQ_SCREEN.out.txt.map { _meta, f -> f }
    versions      = FASTQ_SCREEN_INDEX.out.versions.mix(FASTQ_SCREEN.out.versions)
}
