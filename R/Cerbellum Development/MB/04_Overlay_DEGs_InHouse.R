library(DESeq2)
library(pheatmap)
library(readxl)
library(stringr)
library(dplyr)
library(ggplot2)
Plotting_directory = "HD_Poster/"
Bulk_RNA_files=list()
Bulk_RNA_files = list.files("/hpc/pmc_kool/fvalzano/pipelines_fv_output/Data_fetching/Requests/20240829_Chris")
#Read the bulkRNA seq runs
Bulk_RNA = list()
for(i in Bulk_RNA_files) {
    Bulk_RNA[[i]] = read.table(paste0("/hpc/pmc_kool/fvalzano/pipelines_fv_output/Data_fetching/Requests/20240829_Chris/", i))
    Bulk_RNA[[i]]= Bulk_RNA[[i]][, c("V2", "V11")]
    colnames(Bulk_RNA[[i]]) = c("Counts", "Gene_name")
}
#Something is weird with the first run - probably someone modified it and saved it?
#Remove the extra row from first BulkRNA run
Bulk_RNA[[1]][1,] = NA
Bulk_RNA[[1]] = na.omit(Bulk_RNA[[1]])
#Check that number of rows now is equal to the rest of bulkRNA runs (60357)
nrow(Bulk_RNA[[1]])
Bulk_RNA_merged = list()
Bulk_RNA_merged = Bulk_RNA[[1]]
for (i in 2:length(Bulk_RNA)) {
  Bulk_RNA_merged <- cbind(Bulk_RNA_merged, Bulk_RNA[[i]])
}
##Remove Gene_name columns duplicates
Bulk_RNA_merged = as.data.frame(Bulk_RNA_merged, row.names = Bulk_RNA_merged$Gene_name)
Bulk_RNA_merged = Bulk_RNA_merged[, -grep("Gene_name", names(Bulk_RNA_merged))]

#Retrieve MB subgroup information - Info was provided by Chris
PMCID=read.table("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/List_PMCID_MB_PMC/PMCID.txt")
PMCID=PMCID$V1
##Delete prefix
PMCID = gsub("PMCID", "", PMCID)
Subgroup = c('G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','Wnt','Wnt','Wnt','Wnt','Wnt','Wnt','Wnt','Wnt','Wnt','Wnt')
PMCID_Subgroup = data.frame(PMCID, Subgroup)

#Load general overview to get the Biomaterial ID matching the PMCID
#One ID has a double entry, delete for now the entry with no info and use the one we are sure is a primary tumor
Overview = read_xlsx("/hpc/pmc_kool/fvalzano/Overview/General_overview_patient_seqdata_ForHPC.xlsx")
Overview=Overview %>% 
  mutate(across(where(is.character), str_trim))
print(Overview[,1], n = 70)
#Overview[c(30,29),] = NA
PMCID_Subgroup_merged = merge(PMCID_Subgroup, Overview, by = "PMCID")
PMCID_Subgroup_merged = PMCID_Subgroup_merged[, c("PMCID", "Subgroup", "RNAseq Patient Biomaterial")]
PMCID_Subgroup_merged = na.omit(PMCID_Subgroup_merged)
PMCID_Subgroup_merged = unique(PMCID_Subgroup_merged)

#Get the biomaterial ID in the same order as they were fetched from the bioinformatic server
Bulk_RNA_files_split = strsplit(Bulk_RNA_files, "_")
BiomaterialID_ordered = list()
for(i in seq_along(Bulk_RNA_files_split)){
    BiomaterialID_ordered[i] = Bulk_RNA_files_split[[i]][1]
    BiomaterialID_ordered = as.character(BiomaterialID_ordered)
}

#Reorder the working dataframe according to the order of fetching from the bioinformatic server
PMCID_Subgroup_ordered <- PMCID_Subgroup_merged[match(BiomaterialID_ordered, PMCID_Subgroup_merged$'RNAseq Patient Biomaterial'), ]
#Apply names on Bulk_RNA_merged dataframe
colnames(Bulk_RNA_merged) = PMCID_Subgroup_ordered$PMCID
#set up deseq2 design
design = as.data.frame(PMCID_Subgroup_ordered$Subgroup)
colnames(design) = "Subgroup"
rownames(design) = colnames(Bulk_RNA_merged)
#Generate dds object
#First column is somehow converted in chr, convert in integer
Bulk_RNA_merged$'451AAA' = as.integer(Bulk_RNA_merged$'451AAA')
dds <- DESeqDataSetFromMatrix(countData = Bulk_RNA_merged,
                              colData = design,
                              design = ~ Subgroup)

##QC the dds object
smallestGroupSize <- 3
retain <- rowSums(counts(dds) >= 10) >= smallestGroupSize
dds <- dds[retain,]
#Normalize counts with vst
dds_vst = vst(dds, blind=FALSE)
#As the triple combination displayed interesting enrichment results, we will focus on the
#upregulated genes in this combination and screen how they look in the patients.
#For the purpose of the poster we will focus on the subset of genes highlighted in the enrichment results

MDG_vs_MD = read.csv2("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/MYCN_DNTP53_GLI2_vs_MYCN.DNTP53.csv")
MDG_pattern = MDG_vs_MD[order(MDG_vs_MD$log2FoldChange, decreasing = T),]
MDG_pattern_top = MDG_pattern
#From the genes popping out from the enrichment analysis, only PTCH1, EGFR and GLI2 are significant in the comparison between MDG vs E
dds_vst_subset = dds_vst[rownames(dds_vst) %in% c("PTCH1", "EGFR", "GLI2"),]
Bulk_RNA_vst = as.data.frame(assay(dds_vst_subset))
Bulk_RNA_vst = as.data.frame(Bulk_RNA_vst)

annotation = PMCID_Subgroup_ordered
annotation$'RNAseq Patient Biomaterial' = NULL
rownames(annotation) = annotation$PMCID
annotation$PMCID = NULL
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "Overlay_patients_Heatmap_sub.pdf"), height = 2.5, width = 7.5)
pheatmap(Bulk_RNA_vst, scale = "none", annotation = annotation, cluster_row = T, cluster_col = T, show_colnames = F, color=colorRampPalette(c("white", "pink", "red"))(100))
dev.off()


#To broaden our overview, we need to focus not only on the subset of genes
#coming from the enrichment analysis. This was a good first hint but we need
#to broaden the analysis. In order to do so, we concatenated the two DEG analysis
#performed on MDG. Genes present in MDGvsMD will give us GOI different in the two models
#MDGvsE will give us genes differentially expressed from the "healthy" ctrl.
#Load the two DEG analysis
MDG_vs_MD = read.csv2("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/MYCN_DNTP53_GLI2_vs_MYCN.DNTP53.csv")
MDG_vs_E = read.csv2("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/MYCN_DNTP53_GLI2_vs_EMPTY.csv")
#Combine the two DEGs to have a combo DEG with only genes present in the two
MDG_combo_genes = MDG_vs_E[MDG_vs_E$X %in% MDG_vs_MD$X,]
#Select upregulated genes in MDG
MDG_pattern = MDG_combo_genes[order(MDG_combo_genes$log2FoldChange, decreasing = T),]
MDG_pattern_onlypos = MDG_pattern[MDG_pattern$log2FoldChange>0,]$X
#Plot heatmap of the genes upregulated on patients data
dds_vst_subset = dds_vst[rownames(dds_vst) %in% MDG_pattern_onlypos,]
Bulk_RNA_vst = as.data.frame(assay(dds_vst_subset))
Bulk_RNA_vst = as.data.frame(Bulk_RNA_vst)
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "Overlay_patients_Heatmap_MDG_unique_upregulated.pdf"), height = 20, width = 12.5)
pheatmap(Bulk_RNA_vst, scale = "row", annotation = annotation, cluster_row = T, cluster_col = T, show_colnames = F, color=colorRampPalette(c("blue", "white", "red"))(100))
dev.off()

#Check whether unique upregulated genes in MDG are upregulated in medulloblastoma compared to ETMR
Bulk_RNA_files_MB = list.files("/hpc/pmc_kool/fvalzano/pipelines_fv_output/Data_fetching/Requests/20240829_Chris")
#Read the bulkRNA seq runs
Bulk_RNA_MB = list()
for(i in Bulk_RNA_files_MB) {
    Bulk_RNA_MB[[i]] = read.table(paste0("/hpc/pmc_kool/fvalzano/pipelines_fv_output/Data_fetching/Requests/20240829_Chris/", i))
    Bulk_RNA_MB[[i]]= Bulk_RNA_MB[[i]][, c("V2", "V11")]
    colnames(Bulk_RNA_MB[[i]]) = c("Counts", "Gene_name")
}
#Something is weird with the first run - probably someone modified it and saved it?
#Remove the extra row from first BulkRNA run
Bulk_RNA_MB[[1]][1,] = NA
Bulk_RNA_MB[[1]] = na.omit(Bulk_RNA_MB[[1]])
#Check that number of rows now is equal to the rest of bulkRNA runs (60357)
nrow(Bulk_RNA_MB[[1]])
Bulk_RNA_merged_MB = list()
Bulk_RNA_merged_MB = Bulk_RNA_MB[[1]]
for (i in 2:length(Bulk_RNA_MB)) {
  Bulk_RNA_merged_MB <- cbind(Bulk_RNA_merged_MB, Bulk_RNA_MB[[i]])
}
##Remove Gene_name columns duplicates
Bulk_RNA_merged_MB = as.data.frame(Bulk_RNA_merged_MB, row.names = Bulk_RNA_merged_MB$Gene_name)
Bulk_RNA_merged_MB = Bulk_RNA_merged_MB[, -grep("Gene_name", names(Bulk_RNA_merged_MB))]

#Retrieve MB subgroup information - Info was provided by Chris
PMCID_MB=read.table("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/List_PMCID_PMC/PMCID_MB.txt")
PMCID_MB=PMCID_MB$V1
##Delete prefix
PMCID_MB = gsub("PMCID", "", PMCID_MB)
Subgroup = c('G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G3','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','G4','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','SHH','Wnt','Wnt','Wnt','Wnt','Wnt','Wnt','Wnt','Wnt','Wnt','Wnt')
PMCID_MB_Subgroup = data.frame(PMCID_MB, Subgroup)
colnames(PMCID_MB_Subgroup) = c("PMCID", "Subgroup")
#Load general overview to get the Biomaterial ID matching the PMCID
#One ID has a double entry, delete for now the entry with no info and use the one we are sure is a primary tumor
Overview = read_xlsx("/hpc/pmc_kool/fvalzano/Overview/General_overview_patient_seqdata_ForHPC.xlsx")
Overview=Overview %>% 
  mutate(across(where(is.character), str_trim))
print(Overview[,1], n = 70)
#Overview[c(30,29),] = NA
PMCID_MB_Subgroup_merged = merge(PMCID_MB_Subgroup, Overview, by = "PMCID")
PMCID_MB_Subgroup_merged = PMCID_MB_Subgroup_merged[, c("PMCID", "Subgroup", "RNAseq Patient Biomaterial")]
PMCID_MB_Subgroup_merged = na.omit(PMCID_MB_Subgroup_merged)
PMCID_MB_Subgroup_merged = unique(PMCID_MB_Subgroup_merged)

#Get the biomaterial ID in the same order as they were fetched from the bioinformatic server
Bulk_RNA_files_split = strsplit(Bulk_RNA_files_MB, "_")
BiomaterialID_ordered = list()
for(i in seq_along(Bulk_RNA_files_split)){
    BiomaterialID_ordered[i] = Bulk_RNA_files_split[[i]][1]
    BiomaterialID_ordered = as.character(BiomaterialID_ordered)
}

#Reorder the working dataframe according to the order of fetching from the bioinformatic server
PMCID_Subgroup_ordered_MB <- PMCID_MB_Subgroup_merged[match(BiomaterialID_ordered, PMCID_MB_Subgroup_merged$'RNAseq Patient Biomaterial'), ]
#Apply names on Bulk_RNA_merged dataframe
colnames(Bulk_RNA_merged_MB) = PMCID_Subgroup_ordered_MB$PMCID
Bulk_RNA_merged_MB$'451AAA' = as.integer(Bulk_RNA_merged_MB$'451AAA')
#Load ETMR data
Bulk_RNA_files_ETMR = list.files("/hpc/pmc_kool/fvalzano/pipelines_fv_output/Data_fetching/Requests/20240906_Francesco")
Bulk_RNA_ETMR = list()
for(i in Bulk_RNA_files_ETMR) {
    Bulk_RNA_ETMR[[i]] = read.table(paste0("/hpc/pmc_kool/fvalzano/pipelines_fv_output/Data_fetching/Requests/20240906_Francesco/", i))
    Bulk_RNA_ETMR[[i]]= Bulk_RNA_ETMR[[i]][, c("V2", "V11")]
    colnames(Bulk_RNA_ETMR[[i]]) = c("Counts", "Gene_name")
}
#Merge ETMR data in one dataframe
Bulk_RNA_merged_ETMR = list()
Bulk_RNA_merged_ETMR = Bulk_RNA_ETMR[[1]]
for (i in 2:length(Bulk_RNA_ETMR)) {
  Bulk_RNA_merged_ETMR <- cbind(Bulk_RNA_merged_ETMR, Bulk_RNA_ETMR[[i]])
}
#Assign every column to correspondent ID
PMCID_ETMR=read.table("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/List_PMCID_PMC/PMCID_ETMR.txt")
PMCID_ETMR=PMCID_ETMR$V1
##Delete prefix
PMCID_ETMR = gsub("PMCID", "", PMCID_ETMR)
Subgroup = rep("ETMR", each = 3)
PMCID_Subgroup_ETMR = data.frame(PMCID_ETMR, Subgroup)
colnames(PMCID_Subgroup_ETMR) = c("PMCID", "Subgroup")
##Remove Gene_name columns duplicates
Bulk_RNA_merged_ETMR = as.data.frame(Bulk_RNA_merged_ETMR, row.names = Bulk_RNA_merged_ETMR$Gene_name)
Bulk_RNA_merged_ETMR = Bulk_RNA_merged_ETMR[, -grep("Gene_name", names(Bulk_RNA_merged_ETMR))]
colnames(Bulk_RNA_merged_ETMR) = PMCID_Subgroup_ETMR$PMCID
#remove duplicates in the two datasets - 1553 out of 60357 genes - majority of these genes have 0 counts so it won't be impactful getting rid of these
Bulk_RNA_merged_MB_unique = Bulk_RNA_merged_MB[unique(rownames(Bulk_RNA_merged_MB)),]
Bulk_RNA_merged_ETMR_unique = Bulk_RNA_merged_ETMR[unique(rownames(Bulk_RNA_merged_ETMR)),]
Bulk_RNA_merged = cbind(Bulk_RNA_merged_MB_unique, Bulk_RNA_merged_ETMR_unique)

#set up deseq2 design
design = as.data.frame(c(PMCID_Subgroup_ordered_MB$Subgroup, PMCID_Subgroup_ETMR$Subgroup))
colnames(design) = "Subgroup"
rownames(design) = colnames(Bulk_RNA_merged)
#Generate dds object
dds <- DESeqDataSetFromMatrix(countData = Bulk_RNA_merged,
                              colData = design,
                              design = ~ Subgroup)

##QC the dds object
smallestGroupSize <- 3
retain <- rowSums(counts(dds) >= 10) >= smallestGroupSize
dds <- dds[retain,]
#Normalize counts with vst
dds_vst = vst(dds, blind=FALSE)

#Overlay Genes upregulated in MDG
MDG_vs_MD = read.csv2("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/MYCN_DNTP53_GLI2_vs_MYCN.DNTP53.csv")
MDG_vs_E = read.csv2("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/MYCN_DNTP53_GLI2_vs_EMPTY.csv")
#Combine the two DEGs to have a combo DEG with only genes present in the two
MDG_combo_genes = MDG_vs_E[MDG_vs_E$X %in% MDG_vs_MD$X,]
#Select upregulated genes in MDG
MDG_pattern = MDG_combo_genes[order(MDG_combo_genes$log2FoldChange, decreasing = T),]
MDG_pattern_onlypos = MDG_pattern[MDG_pattern$log2FoldChange>0,]$X
#Plot heatmap of the genes upregulated on patients data
dds_vst_subset = dds_vst[rownames(dds_vst) %in% MDG_pattern_onlypos,]
Bulk_RNA_vst = as.data.frame(assay(dds_vst_subset))
Bulk_RNA_vst = as.data.frame(Bulk_RNA_vst)




pheatmap(Bulk_RNA_vst, scale = "row", annotation = design, cluster_row = T, cluster_col = T, show_colnames = F, color=colorRampPalette(c("blue", "white", "red"))(100))

