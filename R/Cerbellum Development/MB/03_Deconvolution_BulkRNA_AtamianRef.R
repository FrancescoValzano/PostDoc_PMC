library(Seurat)
library(dplyr)
library(readr)
library(MuSiC)
library(MuSiC2)
library(biomaRt)
library(scater)
library(reshape2)
library(ggplot2)
library(cowplot)

#Generate ensembl object for gene ID translation
ensembl <- useMart("ensembl", dataset = "hsapiens_gene_ensembl")
#List Bulk RNA files
Bulk_RNA_files = list.files("/hpc/pmc_kool/Bulk_RNA/Chris_organoids/90-1056583614/01_analysis/hit-counts")
#Read the bulkRNA seq runs
Bulk_RNA = list()
for(i in Bulk_RNA_files) {
    Bulk_RNA[[i]] = read.delim(paste0("/hpc/pmc_kool/Bulk_RNA/Chris_organoids/90-1056583614/01_analysis/hit-counts/", i))
}
#Fetch the ENSG from one run (whatever run is fine, the genes are in the same order in all the runs)
ENSG = Bulk_RNA[[2]][1]
#Merge RNAseq runs - avoid the first one, containing another bulkRNA experiment
Bulk_RNA_merge = as.data.frame(c(Bulk_RNA[[2]][7],
                         Bulk_RNA[[3]][7],
                         Bulk_RNA[[4]][7],
                         Bulk_RNA[[5]][7],
                         Bulk_RNA[[6]][7],
                         Bulk_RNA[[7]][7],
                         Bulk_RNA[[8]][7],
                         Bulk_RNA[[9]][7],
                         Bulk_RNA[[10]][7],
                         Bulk_RNA[[11]][7],
                         Bulk_RNA[[12]][7]))
#Transfer the ENSG ID to merged Bulk RNA dataframe and use them as rownames
Bulk_RNA_merge$Geneid = ENSG$Geneid
rownames(Bulk_RNA_merge) = Bulk_RNA_merge$Geneid

#Convert ENSG IDs in Gene Symbols - the genes are always the same in all the runs so it is enough to just get the list from one run
Gene_symbol = getBM(attributes = c("ensembl_gene_id", "hgnc_symbol"),
                    filters = "ensembl_gene_id",
                    values = Bulk_RNA_merge$Geneid,
                    mart = ensembl)
colnames(Gene_symbol) = c("Geneid", "Gene_symbol")
#Attach Gene_symbol to RNA seq runs
Bulk_RNA_merge = merge(Bulk_RNA_merge, Gene_symbol, by="Geneid")
#Substitute empty slots (pseudogenes without gene symbol) into NA
Bulk_RNA_merge[Bulk_RNA_merge == ""] = NA
#Remove the NAs (pseudogenes)
Bulk_RNA_merge = na.omit(Bulk_RNA_merge)
#Add "_1" to potential duplicated gene_symbols
Bulk_RNA_merge$Gene_symbol = make.unique(Bulk_RNA_merge$Gene_symbol)
#Set Gene_symbol as rownames and drop the ENSGID
rownames(Bulk_RNA_merge) = Bulk_RNA_merge$Gene_symbol
Bulk_RNA_merge$Geneid = NULL
Bulk_RNA_merge$Gene_symbol = NULL

#Music deconvolution based on Atamian dataset
#Create RNA_v3 slot, Seurat v5 is not compatible with MuSiC
Atamian_integrated = readRDS("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/Atamian/Seurat_files/Atamian_integrated.rds")
Atamian_integrated[["RNA3"]] <- as(Atamian_integrated[["RNA"]], Class = "Assay")
DefaultAssay(Atamian_integrated) <- "RNA3"
Atamian_integrated[["RNA"]] <- NULL
Atamian_integrated <- RenameAssays(Atamian_integrated, RNA3 = 'RNA')
Atamian_integrated_sce = as.SingleCellExperiment(Atamian_integrated, assay = "RNA")
#Don't forget to convert the BulkRNA merged dataframe into a matrix
Bulk_RNA_merge = as.matrix(Bulk_RNA_merge)
Est.prop.fullannotations = music_prop(bulk.mtx = Bulk_RNA_merge, sc.sce = Atamian_integrated_sce, clusters = 'final_clusters',
                               samples = 'orig.ident', verbose = T)
#NNLS proportions estimation
Est.prop.nnls = melt(Est.prop.fullannotations$Est.prop.allgene)
colnames(Est.prop.nnls) = c("Sample", "Celltype", "Prop")
p1 = ggplot(Est.prop.nnls, aes(fill=Est.prop.nnls$Celltype, y=Est.prop.nnls$Prop, x=Est.prop.nnls$Sample)) + 
    geom_bar(position="stack", stat="identity")+
    theme(axis.text.x=element_text(angle = 45, hjust = 1, size = 12.5))                      
#MuSiC proportions estimation
Est.prop.music = melt(Est.prop.fullannotations$Est.prop.weighted)
colnames(Est.prop.music) = c("Sample", "Celltype", "Prop")
p2 = ggplot(Est.prop.music, aes(fill=Est.prop.music$Celltype, y=Est.prop.music$Prop, x=Est.prop.music$Sample)) + 
    geom_bar(position="stack", stat="identity")+
    theme(axis.text.x=element_text(angle = 45, hjust = 1, size = 12.5))                      
p1 + p2



