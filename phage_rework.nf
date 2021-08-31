#!/usr/bin/env nextflow
nextflow.enable.dsl=2

/*
* Nextflow -- What the Phage
* Author: christian.jena@gmail.com
*/

/* 
Nextflow version check  
Format is this: XX.YY.ZZ  (e.g. 20.07.1)
change below
*/

XX = "20"
YY = "07"
ZZ = "1"

if ( nextflow.version.toString().tokenize('.')[0].toInteger() < XX.toInteger() ) {
println "\033[0;33mWtP requires at least Nextflow version " + XX + "." + YY + "." + ZZ + " -- You are using version $nextflow.version\u001B[0m"
exit 1
}
else if ( nextflow.version.toString().tokenize('.')[1].toInteger() == XX.toInteger() && nextflow.version.toString().tokenize('.')[1].toInteger() < YY.toInteger() ) {
println "\033[0;33mWtP requires at least Nextflow version " + XX + "." + YY + "." + ZZ + " -- You are using version $nextflow.version\u001B[0m"
exit 1
}

println "_____ _____ ____ ____ ___ ___ __ __ _ _ "
println "  __      _______________________ "
println " /  \\    /  \\__    ___/\\______   \\"
println " \\   \\/\\/   / |    |    |     ___/"
println "  \\        /  |    |    |    |    "
println "   \\__/\\  /   |____|    |____|    "
println "        \\/                        "
println "_____ _____ ____ ____ ___ ___ __ __ _ _ "

if (params.help) { exit 0, helpMSG() }

println " "
println "\u001B[32mProfile: $workflow.profile\033[0m"
println " "
println "\033[2mCurrent User: $workflow.userName"
println "Nextflow-version: $nextflow.version"
println "WtP intended for Nextflow-version: 20.01.0"
println "Starting time: $nextflow.timestamp"
println "Workdir location [--workdir]:"
println "  $workflow.workDir"
println "Output location [--output]:"
println "  $params.output"
println "\033[2mDatabase location [--databases]:"
println "  $params.databases\u001B[0m"
if (workflow.profile.contains('singularity')) {
println "\033[2mSingularity cache location [--cachedir]:"
println "  $params.cachedir"
println "  "
println "\u001B[33m  WARNING: Singularity image building sometimes fails!"
println "  Please download all images first via --setup --cachedir IMAGE-LOCATION"
println "  Manually remove faulty images in $params.cachedir for a rebuild\u001B[0m"
}
if (params.annotate) { println "\u001B[33mSkipping phage identification for fasta files\u001B[0m" }
if (params.identify) { println "\u001B[33mSkipping phage annotation\u001B[0m" }
println " "
println "\033[2mCPUs to use: $params.cores, maximal CPUs to use: $params.max_cores\033[0m"
println " "

/************* 
* ERROR HANDLING
*************/
// profiles
if ( workflow.profile == 'standard' ) { exit 1, "NO VALID EXECUTION PROFILE SELECTED, use e.g. [-profile local,docker]" }

if (
    workflow.profile.contains('singularity') ||
    workflow.profile.contains('ukj_cloud') ||
    workflow.profile.contains('stub') ||
    workflow.profile.contains('docker')
    ) { "engine selected" }
else { exit 1, "No engine selected:  -profile EXECUTER,ENGINE" }

if (
    workflow.profile.contains('local') ||
    workflow.profile.contains('test') ||
    workflow.profile.contains('smalltest') ||
    workflow.profile.contains('ebi') ||
    workflow.profile.contains('slurm') ||
    workflow.profile.contains('lsf') ||
    workflow.profile.contains('ukj_cloud') ||
    workflow.profile.contains('stub') ||
    workflow.profile.contains('git_action')
    ) { "executer selected" }
else { exit 1, "No executer selected:  -profile EXECUTER,ENGINE" }

// params tests
if (!params.setup && !workflow.profile.contains('test') && !workflow.profile.contains('smalltest')) {
    if ( !params.fasta && !params.fastq ) {
        exit 1, "input missing, use [--fasta] or [--fastq]"}
    if ( params.ma && params.mp && params.vf && params.vs && params.pp && params.dv && params.sm && params.vn && params.vb && params.ph && params.vs2 && params.sk ) {
        exit 0, "What the... you deactivated all the tools"}
}

/************* 
* INPUT HANDLING
*************/

// fasta input or via csv file, fasta input is deactivated if test profile is choosen
    if (params.fasta && params.list && !workflow.profile.contains('test') ) { fasta_input_ch = Channel
            .fromPath( params.fasta, checkIfExists: true )
            .splitCsv()
            .map { row -> ["${row[0]}", file("${row[1]}", checkIfExists: true)] }
                }
    else if (params.fasta && !workflow.profile.contains('test') ) { fasta_input_ch = Channel
            .fromPath( params.fasta, checkIfExists: true)
            .map { file -> tuple(file.baseName, file) }
                }
    
// fastq input or via csv file
    if (params.fastq && params.list) { fastq_input_ch = Channel
            .fromPath( params.fastq, checkIfExists: true )
            .splitCsv()
            .map { row -> ["${row[0]}", file("${row[1]}", checkIfExists: true)] }
                }
    else if (params.fastq) { fastq_input_ch = Channel
            .fromPath( params.fastq, checkIfExists: true)
            .map { file -> tuple(file.baseName, file) }
                }

//get-citation-file for results
    citation = Channel.fromPath(workflow.projectDir + "/docs/Citations.bib")
            .collectFile(storeDir: params.output + "/literature")


/************* 
* DATABASES for Phage annotation
*************/

workflow pvog_database {
    main: 
        // local storage via storeDir
        if (!params.cloudProcess) { pvog_DB(); db = pvog_DB.out }
        // cloud storage via db_preload.exists()
        if (params.cloudProcess) {
            db_preload = file("${params.databases}/pvogs/", type: 'dir')
            if (db_preload.exists()) { db = db_preload }
            else  { pvog_DB(); db = pvog_DB.out } 
        }
    emit: db
}

workflow vogtable_database {
    main: 
        // local storage via storeDir
        if (!params.cloudProcess) { vogtable_DB(); db = vogtable_DB.out }
        // cloud storage via db_preload.exists()
        if (params.cloudProcess) {
            db_preload = file("${params.databases}/vog_table/VOGTable.txt")
            if (db_preload.exists()) { db = db_preload }
            else  { vogtable_DB(); db = vogtable_DB.out } 
        }
    emit: db
}

workflow rvdb_database {
    main: 
        // local storage via storeDir
        if (!params.cloudProcess) { rvdb_DB(); db = rvdb_DB.out }
        // cloud storage via db_preload.exists()
        if (params.cloudProcess) {
            db_preload = file("${params.databases}/rvdb", type: 'dir')
            if (db_preload.exists()) { db = db_preload }
            else  { rvdb_DB(); db = rvdb_DB.out } 
        }
    emit: db
}

workflow vog_database {
    main: 
        // local storage via storeDir
        if (!params.cloudProcess) { vog_DB(); db = vog_DB.out }
        // cloud storage via db_preload.exists()
        if (params.cloudProcess) {
            db_preload = file("${params.databases}/vog/vogdb", type: 'dir')
            if (db_preload.exists()) { db = db_preload }
            else  { vog_DB(); db = vog_DB.out } 
        }
    emit: db
}

workflow checkV_database {
    main: 
        // local storage via storeDir
        if (!params.cloudProcess) { download_checkV_DB(); db = download_checkV_DB.out }
        // cloud storage via db_preload.exists()
        if (params.cloudProcess) {
            db_preload = file("${params.databases}/checkV/checkv-db-v0.6", type: 'dir')
            if (db_preload.exists()) { db = db_preload }
            else  { download_checkV_DB(); db = download_checkV_DB.out } 
        }
    emit: db
}

/************* 
* SUB WORKFLOWS
*************/


workflow setup_wf {
    take:   
    main:       
        // docker
        if (workflow.profile.contains('docker')) {
            config_ch = Channel.fromPath( workflow.projectDir + "/configs/container.config" , checkIfExists: true)
            setup_container(config_ch)
        }
        // singularity
        if (workflow.profile.contains('singularity')) {
            config_ch2 = Channel.fromPath( workflow.projectDir + "/configs/container.config" , checkIfExists: true)
            setup_container(config_ch2)
        }

        // databases
        if (!params.annotate) {
            phage_references() 
            ref_phages_DB = phage_blast_DB (phage_references.out)
            ppr_deps = ppr_dependecies()
            sourmash_DB = sourmash_database (phage_references.out)
            vibrant_DB = vibrant_download_DB()
            virsorter_DB = virsorter_database()
            virsorter2_DB = virsorter2_download_DB()
        }
        if (!params.identify) {
            vog_table = vogtable_database()
            pvog_DB = pvog_database() 
            vog_DB = vog_database() 
            rvdb_DB = rvdb_database()
            checkV_DB = checkV_database()
        }
} 

workflow checkV_wf {
    take:   fasta
            database
    main:   checkV(fasta, database)

            /* filter_tool_names.out in identify_fasta_MSF is the info i need to parse into checkV overview 
            has tuple val(name), file("*.txt")
            
            each txt file can be present or not

            1.) parse this output into a "contig name", 1, 0" matrix still having the "value" infront of it

            2.) then i could do a join first bei val(name), an then combine by val(contigname) within the channels?

            3.) annoying ...

            */
    emit:   checkV.out
} 

workflow get_test_data {
    main: testprofile()
    emit: testprofile.out.flatten().map { file -> tuple(file.simpleName, file) }
}

workflow phage_tax_classification {
    take:   fasta
            sourmash_database
    main:    
            sourmash_for_tax(split_multi_fasta_2(fasta), sourmash_database).groupTuple(remainder: true)
}

/************* 
* MainSubWorkflows
*************/

workflow identify_fasta_MSF {
    take:   fasta
            ref_phages_DB
            ppr_deps
            sourmash_DB
            vibrant_DB
            virsorter_DB
            virsorter2_DB
    main: 
        // input filter  
        fasta_validation_wf(fasta)

        // gather results
            results =   virsorter_wf(fasta_validation_wf.out, virsorter_DB)
                        .concat(virsorter2_wf(fasta_validation_wf.out, virsorter2_DB))
                        .concat(virsorter_virome_wf(fasta_validation_wf.out, virsorter_DB))
                        // depracted due to file size explosin -> .concat(marvel_wf(fasta_validation_wf.out))      
                        .concat(sourmash_wf(fasta_validation_wf.out, sourmash_DB))
                        .concat(metaphinder_wf(fasta_validation_wf.out))
                        .concat(metaphinder_own_DB_wf(fasta_validation_wf.out, ref_phages_DB))
                        .concat(deepvirfinder_wf(fasta_validation_wf.out))
                        .concat(virfinder_wf(fasta_validation_wf.out))
                        .concat(pprmeta_wf(fasta_validation_wf.out, ppr_deps))
                        .concat(vibrant_wf(fasta_validation_wf.out, vibrant_DB))
                        .concat(vibrant_virome_wf(fasta_validation_wf.out, vibrant_DB))
                        .concat(virnet_wf(fasta_validation_wf.out))
                        .concat(phigaro_wf(fasta_validation_wf.out))
                        .concat(seeker_wf(fasta_validation_wf.out))
                        .filter { it != 'deactivated' } // removes deactivated tool channels
                        .groupTuple()
                                               
        //plotting overview
            filter_tool_names(results)
            upsetr_plot(filter_tool_names.out[0])        

    emit:   output = fasta_validation_wf.out.join(results)  // val(name), path(fasta), path(scores_by_tools)
}


workflow phage_annotation_MSF {
    take:   fasta_and_tool_results 
            pvog_DB
            vog_table
            vog_DB
            rvdb_DB
    main:  
            
            fasta = fasta_and_tool_results.map {it -> tuple(it[0],it[1])}
            //annotation-process

            prodigal(fasta)

            hmmscan(prodigal.out, pvog_DB)

            score_based_chunking(hmmscan.out.join(fasta_and_tool_results), vog_table)
            
            chunk_channel=score_based_chunking.out[0].mix(score_based_chunking.out[1]).mix(score_based_chunking.out[2]).mix(score_based_chunking.out[3])
            
            chromomap_parser(chunk_channel.combine(hmmscan.out, by:0), vog_table)
            chromomap(chromomap_parser.out[0].mix(chromomap_parser.out[1]))

            // fine granular heatmap ()

            hue_heatmap(fasta_and_tool_results)

    emit:   chunk_channel.view()
}

/************* 
* MAIN WORKFLOWS
*************/

/************************** 
* Workflows
**************************/

include { input_validation_wf } from './workflows/input_validation_wf'
include { deepvirfinder_wf } from './workflows/deepvirfinder_wf.nf'
include { phigaro_wf } from './workflows/phigaro_wf'
include { seeker_wf } from './workflows/seeker_wf'
include { virfinder_wf } from './workflows/virfinder_wf'
include { virnet_wf } from './workflows/virnet_wf'

workflow{

/************************** 
* Input validation
**************************/
    input_validation_wf(fasta_input_ch)


/************************** 
* Databases
**************************/



/************************** 
* Identification
**************************/
    results = deepvirfinder_wf(input_validation_wf.out)
              .concat( phigaro_wf(input_validation_wf.out))
              .concat( seeker_wf(input_validation_wf.out))
              .concat( virfinder_wf(input_validation_wf.out))
              .concat( virnet_wf(input_validation_wf.out))
              .filter { it != 'deactivated' } // removes deactivated tool channels
              .groupTuple()



/************************** 
* Annotation
**************************/






}



// workflow {
// // SETUP AND TESTRUNS
// if (params.setup) { setup_wf() }
// else {
//     if (workflow.profile.contains('test') && !workflow.profile.contains('smalltest')) { fasta_input_ch = get_test_data() }
//     if (workflow.profile.contains('smalltest') ) 
//         { fasta_input_ch = Channel.fromPath(workflow.projectDir + "/test-data/all_pos_phage.fa", checkIfExists: true).map { file -> tuple(file.simpleName, file) }.view() }
// // DATABASES
//     // identification
//     //phage_references() 
//     if (params.mp || params.annotate) { ref_phages_DB = Channel.from( [ 'deactivated', 'deactivated'] ) } else { ref_phages_DB = phage_blast_DB(phage_references.out) }
//     if (params.pp || params.annotate) { ppr_deps = Channel.from( [ 'deactivated', 'deactivated'] ) } else { ppr_deps = ppr_dependecies() }
//     if (params.vb || params.annotate) { vibrant_DB = Channel.from( [ 'deactivated', 'deactivated'] ) } else { vibrant_DB = vibrant_database() }
//     if (params.vs || params.annotate) { virsorter_DB = Channel.from( [ 'deactivated', 'deactivated'] ) } else { virsorter_DB = virsorter_database() }
//     if (params.vs2 || params.annotate) { virsorter2_DB = Channel.from( ['deactivated', 'deactivated'] ) } else { virsorter2_DB = virsorter2_database() }
//     //  annotation
//     if (params.identify) { pvog_DB = Channel.from( [ 'deactivated', 'deactivated'] ) } else { pvog_DB = pvog_database() }
//     if (params.identify) { vog_table = Channel.from( [ 'deactivated', 'deactivated'] ) } else { vog_table = vogtable_database() }
//     if (params.identify) { vog_DB = Channel.from( [ 'deactivated', 'deactivated'] ) } else { vog_DB = vog_database() }
//     if (params.identify) { rvdb_DB = Channel.from( [ 'deactivated', 'deactivated'] ) } else { rvdb_DB = rvdb_database() }
//     if (params.identify) { checkV_DB = Channel.from( [ 'deactivated', 'deactivated'] ) } else { checkV_DB = checkV_database() }
//     // sourmash (used in identify and annotate)
//     if (params.identify && params.sm) { sourmash_DB = Channel.from( [ 'deactivated', 'deactivated'] ) } else { sourmash_DB = sourmash_database(phage_references.out) }

// // IDENTIFY !
//     if (params.fasta && !params.annotate) { identify_fasta_MSF(fasta_input_ch, ref_phages_DB, ppr_deps,sourmash_DB, vibrant_DB, virsorter_DB, virsorter2_DB) }
//     if (params.fastq) { identify_fastq_MSF(fastq_input_ch, ref_phages_DB, ppr_deps, sourmash_DB, vibrant_DB, virsorter_DB) }

// // ANNOTATE & TAXONOMY !
//     // generate "annotation_ch" based on input types (fasta/fastq and annotate)
//     if (params.fasta && params.fastq && params.annotate) { annotation_ch = identify_fastq_MSF.out.mix(fasta_validation_wf(fasta_input_ch)) }
//     else if (params.fasta && params.fastq && !params.annotate) { annotation_ch = identify_fastq_MSF.out.mix(identify_fasta_MSF.out) }
//     else if (params.fasta && params.annotate) { annotation_ch = fasta_validation_wf(fasta_input_ch)}
//     else if (params.fasta && !params.annotate) { annotation_ch = identify_fasta_MSF.out }
//     else if (params.fastq ) { annotation_ch = identify_fastq_MSF.out }

//     // Annotation & classification & score based chunking
//     if (!params.identify) { 
//         phage_annotation_MSF(annotation_ch, pvog_DB, vog_table, vog_DB, rvdb_DB) 
        
//         // these workflows are using the score based chunks from phage_annotation_MSF
//         checkV_wf(phage_annotation_MSF.out, checkV_DB) 
//         phage_tax_classification(phage_annotation_MSF.out, sourmash_DB )
//     }
// }}

/*************  
* --help
*************/
def helpMSG() {
    c_green = "\033[0;32m";
    c_reset = "\033[0m";
    c_yellow = "\033[0;33m";
    c_blue = "\033[0;34m";
    c_dim = "\033[2m";
    log.info """
    .
    ${c_yellow}Usage examples:${c_reset}
    nextflow run replikation/What_the_Phage --fasta '*/*.fasta' --cores 20 --max_cores 40 \\
        --output results -profile local,docker 

    nextflow run phage.nf --fasta '*/*.fasta' --cores 20 \\
        --output results -profile lsf,singularity \\
        --cachedir /images/singularity_images \\
        --databases /databases/WtP_databases/ 

    ${c_yellow}Input:${c_reset}
     --fasta             '*.fasta'   -> assembly file(s)
     --fastq             '*.fastq'   -> long read file(s)
    ${c_dim}  ..change above input to csv via --list ${c_reset}  
    ${c_dim}   e.g. --fasta inputs.csv --list    
        the .csv contains per line: name,/path/to/file${c_reset}  
     --setup              skips analysis and just downloads databases and containers

    ${c_yellow}Execution/Engine profiles:${c_reset}
     WtP supports profiles to run via different ${c_green}Executers${c_reset} and ${c_blue}Engines${c_reset} e.g.:
     -profile ${c_green}local${c_reset},${c_blue}docker${c_reset}

      ${c_green}Executer${c_reset} (choose one):
      slurm
      local
      lsf
      ebi
      ${c_blue}Engines${c_reset} (choose one):
      docker
      singularity
    
    For a test run (~ 1h), add "smalltest" to the profile, e.g. -profile smalltest,local,singularity 
    
    ${c_yellow}Options:${c_reset}
    --filter            min contig size [bp] to analyse [default: $params.filter]
    --cores             max cores per process for local use [default: $params.cores]
    --max_cores         max cores used on the machine for local use [default: $params.max_cores]    
    --output            name of the result folder [default: $params.output]

    ${c_yellow}Tool control:${c_reset}
    Deactivate tools individually by adding one or more of these flags
    --dv                deactivates deepvirfinder
    --ma                deactivates marvel
    --mp                deactivates metaphinder
    --pp                deactivates PPRmeta
    --sm                deactivates sourmash
    --vb                deactivates vibrant
    --vf                deactivates virfinder
    --vn                deactivates virnet
    --vs                deactivates virsorter
    --ph                deactivates phigaro
    --vs2               deactivates virsorter2
    --sk                deactivates seeker

    Adjust tools individually
    --virome            deactivates virome-mode (vibrand and virsorter)
    --dv_filter         p-value cut-off [default: $params.dv_filter]
    --mp_filter         average nucleotide identity [default: $params.mp_filter]
    --vf_filter         score cut-off [default: $params.vf_filter]
    --vs2_filter        dsDNAphage score cut-off [default: $params.vs2_filter]
    --sm_filter         Similarity score [default: $params.sm_filter]
    --vn_filter         Score [default: $params.vn_filter]
    --sk_filter         score cut-off [default: $params.sk_filter]

    Workflow control:
    --identify          only phage identification, skips analysis
    --annotate          only annotation, skips phage identification

    ${c_yellow}Databases, file, container behaviour:${c_reset}
    --databases         specifiy download location of databases 
                        [default: ${params.databases}]
                        ${c_dim}WtP downloads DBs if not present at this path${c_reset}

    --workdir           defines the path where nextflow writes temporary files 
                        [default: $params.workdir]

    --cachedir          defines the path where singularity images are cached
                        [default: $params.cachedir] 

    """.stripIndent()
}

if (!params.setup) {
    workflow.onComplete { 
        log.info ( workflow.success ? "\nDone! Results are stored here --> $params.output \nThank you for using What the Phage\n \nPlease cite us: https://doi.org/10.1101/2020.07.24.219899 \
                                      \n\nPlease also cite the other tools we use in our workflow --> $params.output/literature \n" : "Oops .. something went wrong" )
    }
}
