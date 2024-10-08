# General Overview of the folder
This folder contains collections of codes free to use within the PMC_Kool group.

        SCRIPT_DIR=${YourFavouriteDirectory}


Data_fetching: Contains pipeline to fetch bulk RNAsequencing runs from the bioinformatic server of the PMC, it is semi automated, the only thing to be changed are the PMCID of the given samples you want to retrieve in the R script ID_conversion.R (code line 10) and the date and requester in the Data_fetching.sh job script (code line 14 to 16).
A copy of the script used for given requests will be saved under a folder with the date and name of requester.

DESeq2: Contains pipeline to fetch the bulk RNA sequencing fetched with the 'Data_fetching' pipeline and process it to perform DESeq analysis. The only thing to be changed are the ID of the given samples you want to analise in the DESeq2.R script (code line 10) - even though would be nice to have a total automated pipeline, the nature of DESeq analysis varies based on the hypothesis you want to test (different designs), therefore, several minor adjustment might be needed when this analysis is required.
Ideally, one would first run Data_fetching to retrieve the bulk raw counts from the server and then DESeq2 to perform the actual analysis.
A copy of the script used for given requests will be saved under a folder with the date and name of requester.

remapping: Contains all the necessary elements to perform alignment of single cell sequencing fastq files.

pipelines_from_PMC:
    
    bulkRNA_quantification: Contains scripts to use PMC pipelines for bulkRNA sequencing
        
    Barcode input search:
            bash ${SCRIPT_DIR}/Barcodes_search.sh
    Fasta inputs generation script for sequencing performed on multiple lanes:
            bash ${SCRIPT_DIR}/Fasta_inputs_generation_multi_lanes.sh
    Fasta inputs generation script for sequencing performed on single lane
            bash ${SCRIPT_DIR}/Fasta_inputs_generation_single_lane:.sh
    Json file generation script for converting fastq to ubam format:
            bash ${SCRIPT_DIR}/Fastq_ubam_workflow_fv_inputs_json_generation.sh
    Json file generation script for converting ubam to counts format:
            bash ${SCRIPT_DIR}/Rna_fusions_germline_snv_inputs_no_molgenis_fv_generation.sh
        
## Subfolders:
    ITCCP4: Contains scripts used for analysis of the ITCCP4 samples with PMC pipelines for bulkRNA sequencing:
    Script for converting fastq to ubam format, looped for several samples:
            bash ${SCRIPT_DIR}/run_fastq_ubam_workflow_fv_looped.sh
    Script for converting ubam to counts, looped for several samples
            bash ${SCRIPT_DIR}/run_rna_fusion_workflow_fv_looped.sh
    AZ: Contains scripts used for analysis of the AZ samples with PMC pipelines for bulkRNA sequencing:
    Script for converting fastq to ubam format, looped for several samples:
            bash ${SCRIPT_DIR}/run_fastq_ubam_workflow_fv_looped.sh
    Script for converting ubam to counts, looped for several samples
            bash ${SCRIPT_DIR}/run_rna_fusion_workflow_fv_looped.sh
...

Main contributors:
Francesco Valzano
...
