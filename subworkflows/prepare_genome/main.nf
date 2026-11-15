include { STAR_GENOMEGENERATE   } from '../../modules/star/main'
include { RSEM_PREPAREREFERENCE } from '../../modules/rsem/main'
include { BEDTOOLS_INTRONS      } from '../../modules/bedtools/main'
include { GEDI_INDEXGENOME      } from '../../modules/gedi/main'

workflow PREPARE_GENOME {
    take:
    genomes
    need_rsem
    need_introns
    need_gedi

    main:
    versions = channel.empty()
    gtf = genomes.map { g -> [g.id, g.gtf] }

    star = genomes.branch { g ->
        prebuilt: g.star_index
        build: true
    }
    STAR_GENOMEGENERATE(star.build.map { g -> [[id: g.id, genome: g.id], g.fasta, g.gtf] })
    star_index = star.prebuilt.map { g -> [g.id, g.star_index] }
        .mix(STAR_GENOMEGENERATE.out.index.map { meta, dir -> [meta.id, dir] })
    versions = versions.mix(STAR_GENOMEGENERATE.out.versions)

    rsem_index = channel.empty()
    if (need_rsem) {
        rsem = genomes.branch { g ->
            prebuilt: g.rsem_index
            build: true
        }
        RSEM_PREPAREREFERENCE(rsem.build.map { g -> [[id: g.id, genome: g.id], g.fasta, g.gtf] })
        rsem_index = rsem.prebuilt
            .map { g -> [g.id, g.rsem_index, file("${g.rsem_index}/genome.transcripts.fa", checkIfExists: true)] }
            .mix(RSEM_PREPAREREFERENCE.out.index.map { meta, dir, fa -> [meta.id, dir, fa] })
        versions = versions.mix(RSEM_PREPAREREFERENCE.out.versions)
    }

    introns = channel.empty()
    if (need_introns) {
        BEDTOOLS_INTRONS(genomes.map { g -> [[id: g.id, genome: g.id], g.gtf] })
        introns = BEDTOOLS_INTRONS.out.saf.map { meta, saf -> [meta.id, saf] }
        versions = versions.mix(BEDTOOLS_INTRONS.out.versions)
    }

    gedi_index = channel.empty()
    if (need_gedi) {
        gedi = genomes.branch { g ->
            prebuilt: g.gedi_index
            build: true
        }
        GEDI_INDEXGENOME(gedi.build.map { g -> [[id: g.id, genome: g.id], g.fasta, g.gtf] })
        gedi_index = gedi.prebuilt.map { g -> [g.id, g.gedi_index] }
            .mix(GEDI_INDEXGENOME.out.index.map { meta, dir -> [meta.id, dir] })
        versions = versions.mix(GEDI_INDEXGENOME.out.versions)
    }

    emit:
    gtf        = gtf
    star_index = star_index
    rsem_index = rsem_index
    introns    = introns
    gedi_index = gedi_index
    versions   = versions
}
