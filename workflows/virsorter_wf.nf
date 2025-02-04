include { virsorter } from './process/virsorter/virsorter'
include { filter_virsorter } from './process/virsorter/filter_virsorter'
include { virsorter_collect_data } from './process/virsorter/virsorter_collect_data'
include { virsorter_download_DB } from './process/virsorter/virsorter_download_DB'


workflow virsorter_wf {
    take:   fasta
    main:   if (!params.vs) {
                // local storage via storeDir
                if (!params.cloudProcess) { virsorter_download_DB(); db = virsorter_download_DB.out }
                // cloud storage via db_preload.exists()
                if (params.cloudProcess) {
                db_preload = file("${params.databases}/virsorter/virsorter-data", type: 'dir')
                if (db_preload.exists()) { db = db_preload }
                else  { virsorter_download_DB(); db = virsorter_download_DB.out } 
                }
                // tool prediction
                virsorter(fasta, virsorter_download_DB.out)
                // filtering
                filter_virsorter(virsorter.out[0].groupTuple(remainder: true))
                // raw data collector
                virsorter_collect_data(virsorter.out[1].groupTuple(remainder: true))
                // result channel
                virsorter_results = filter_virsorter.out
                }
            else { virsorter_results = Channel.from( [ 'deactivated', 'deactivated'] ) }
    emit:   virsorter_results
} 
