library(DESeq2)
library(purrr)
library(apeglm)
library(ggplot2)
library(umap)
library(uwot)
library(biomaRt)
library(pheatmap)
library(enrichR)
library(clusterProfiler)
library(ggrepel)
Plotting_directory = "HD_Poster/"
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
#Merge RNAseq runs
Bulk_RNA_merge = as.data.frame(c(#Bulk_RNA[[2]][7],
                         Bulk_RNA[[3]][7],
                         Bulk_RNA[[4]][7],
                         Bulk_RNA[[5]][7],
                         #Bulk_RNA[[6]][7],
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

##Write analysis design and set up dds object
design = data.frame(condition = factor(c(#"MYCN", 
                         "MYCN-DNTP53",
                         "MYCN-DNTP53-GLI2", 
                         "EMPTY", 
                         #"MYCN", 
                         "MYCN-DNTP53",
                         "MYCN-DNTP53-GLI2", 
                         "EMPTY", 
                         "MYCN-DNTP53",
                         "MYCN-DNTP53-GLI2", 
                         "EMPTY")))
#Set reference to empty - this will set up the analysis against the empty group
design$condition = relevel(design$condition, ref = "EMPTY")
rownames(design) = colnames(Bulk_RNA_merge)
dds <- DESeqDataSetFromMatrix(countData = Bulk_RNA_merge,
                              colData = design,
                              design = ~ condition)

##QC the dds object
smallestGroupSize <- 3
retain <- rowSums(counts(dds) >= 10) >= smallestGroupSize
dds <- dds[retain,]
##Differentially Expressed Gene Analysis 
dds <- DESeq(dds)
resultsNames(dds)

##Analyze the single comparisons
#MYCN_vs_EMPTY
#LFC shrinkage with apeglm
resLFC <- lfcShrink(dds, coef="condition_MYCN_vs_EMPTY", type="apeglm")
#Get full DEG list
MYCN_vs_EMPTY = as.data.frame(resLFC)
#Filter significant terms for exporting 
MYCN_vs_EMPTY_signif = MYCN_vs_EMPTY[MYCN_vs_EMPTY$padj<=0.05,]
MYCN_vs_EMPTY_signif = na.omit(MYCN_vs_EMPTY_signif)
write.csv2(MYCN_vs_EMPTY_signif, "/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/MYCN_vs_EMPTY.csv")
#Visualize the results via volcano plot
MYCN_vs_EMPTY$gene = rownames(MYCN_vs_EMPTY)
#Add colors
MYCN_vs_EMPTY$cols = ifelse(MYCN_vs_EMPTY$log2FoldChange> 0.75 & MYCN_vs_EMPTY$padj<=0.05, "upregulated", 
                     ifelse(MYCN_vs_EMPTY$log2FoldChange< -0.75 & MYCN_vs_EMPTY$padj<=0.05, "downregulated", "ns"))
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "MYCN_Volcano.pdf"), width = 7.5, height = 7.5)
ggplot(MYCN_vs_EMPTY, aes(x= MYCN_vs_EMPTY$log2FoldChange, y = -log10(MYCN_vs_EMPTY$padj), colour = MYCN_vs_EMPTY$cols))+
    geom_point(aes(size = 2.5))+
    xlim(-5,5)+
    ylim(0,5)+
    geom_hline(yintercept = 1.3, linetype = "dashed")+
    geom_vline(xintercept = c(-0.75, +0.75), linetype = "dashed")+
    theme_bw()+
    xlab("Log2FoldChange")+
    ylab("Significance")+
    theme(axis.text.x = element_text(size = 20),
          axis.text.y = element_text(size = 20),
          axis.title.x = element_text(size = 25),
          axis.title.y = element_text(size = 25),
          legend.position = 'none')+
    scale_colour_manual(values = c("downregulated" = "navyblue",
                          "upregulated" = "darkred",
                          "ns" = "gray")) +
    annotate("text", x = -Inf, y = Inf, label = "Empty cag",
           hjust = -0.1, vjust = 1.1, size = 7.5, color = "navyblue")+
    annotate("text", x = Inf, y = Inf, label = "MYCN",
           hjust = 1.1, vjust = 1.1, size = 7.5, color = "darkred")
dev.off()           
#Visualize top 20 DEG (don't forget to normalise the counts)
dds_vst = vst(dds, blind=FALSE)
Bulk_RNA_vst = as.data.frame(assay(dds_vst))
#Filter for samples of interest
Bulk_RNA_vst_MYCN_Empty = Bulk_RNA_vst[,c("CB2402.03.mix.1.MYCN","CB2402.03.mix.8.empty.cag.ig","CB2410.11.mix.1.MYCN","CB2410.11.mix.8.empty.cag.ig","CB2412.13.mix.8.empty.cag.ig")]
#Filter for genes of interest (in this case we have very little genes, so we will use them all)
MYCN_vs_EMPTY_signif = read.csv2("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/MYCN_vs_EMPTY.csv")
Bulk_RNA_vst_MYCN_Empty = Bulk_RNA_vst_MYCN_Empty[rownames(Bulk_RNA_vst_MYCN_Empty)%in% MYCN_vs_EMPTY_signif$X,]
#Plot
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "top10_DEG_MYCN.pdf"), width = 7.5, height = 7.5)
pheatmap(Bulk_RNA_vst_MYCN_Empty, cluster_row = T, scale = "row",fontsize = 15)
dev.off()
#MYCN-DTP53_vs_EMPTY
#LFC shrinkage with apeglm
resLFC <- lfcShrink(dds, coef="condition_MYCN.DNTP53_vs_EMPTY", type="apeglm")
#Get full DEG list
MYCN_DNTP53_vs_EMPTY = as.data.frame(resLFC)
#Filter significant terms for exporting 
MYCN_DNTP53_vs_EMPTY_signif = MYCN_DNTP53_vs_EMPTY[MYCN_DNTP53_vs_EMPTY$padj<=0.05,]
MYCN_DNTP53_vs_EMPTY_signif = na.omit(MYCN_DNTP53_vs_EMPTY_signif)
write.csv2(MYCN_DNTP53_vs_EMPTY_signif, "/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/MYCN_DNTP53_vs_EMPTY.csv")
#Visualize the results via volcano plot
MYCN_DNTP53_vs_EMPTY$gene = rownames(MYCN_DNTP53_vs_EMPTY)
#Add colors
MYCN_DNTP53_vs_EMPTY$cols = ifelse(MYCN_DNTP53_vs_EMPTY$log2FoldChange> 0.75 & MYCN_DNTP53_vs_EMPTY$padj<=0.05, "upregulated", 
                     ifelse(MYCN_DNTP53_vs_EMPTY$log2FoldChange< -0.75 & MYCN_DNTP53_vs_EMPTY$padj<=0.05, "downregulated", "ns"))
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "MYCN_DNTP53_Volcano.pdf"), width = 7.5, height = 7.5)
ggplot(MYCN_DNTP53_vs_EMPTY, aes(x= MYCN_DNTP53_vs_EMPTY$log2FoldChange, y = -log10(MYCN_DNTP53_vs_EMPTY$padj), colour = MYCN_DNTP53_vs_EMPTY$cols))+
    geom_point(aes(size = 2.5))+
    xlim(-7.5,7.5)+
    ylim(0,max(MYCN_DNTP53_vs_EMPTY$padj)+1)+
    geom_hline(yintercept = 1.3, linetype = "dashed")+
    geom_vline(xintercept = c(-0.75, +0.75), linetype = "dashed")+
    theme_bw()+
    xlab("Log2FoldChange")+
    ylab("Significance")+
    theme(axis.text.x = element_text(size = 20),
          axis.text.y = element_text(size = 20),
          axis.title.x = element_text(size = 25),
          axis.title.y = element_text(size = 25),
          legend.position = 'none')+
    scale_colour_manual(values = c("downregulated" = "navyblue",
                          "upregulated" = "darkred",
                          "ns" = "gray")) +
    annotate("text", x = -Inf, y = Inf, label = "Empty cag",
           hjust = -0.1, vjust = 1.1, size = 7.5, color = "navyblue")+
    annotate("text", x = Inf, y = Inf, label = "MYCN and DNTP53",
           hjust = 1.1, vjust = 1.1, size = 7.5, color = "darkred")
dev.off()
#Visualize top 20 DEG (don't forget to normalise the counts)
dds_vst = vst(dds, blind=FALSE)
Bulk_RNA_vst = as.data.frame(assay(dds_vst))
#Filter for samples of interest
Bulk_RNA_vst_MYCN_DNTP53_Empty = Bulk_RNA_vst[,c("CB2402.03.mix.2.MYCN.DNTP53","CB2402.03.mix.8.empty.cag.ig","CB2410.11.mix.2.MYCN.DNTP53","CB2410.11.mix.8.empty.cag.ig","CB2412.13.mix.2.MYCN.DNTP53","CB2412.13.mix.8.empty.cag.ig"),]
#Filter for genes of interest (we use the top10 DEG in both direction)
MYCN_DNTP53_vs_EMPTY_signif = read.csv2("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/MYCN_DNTP53_vs_EMPTY.csv")
#Order terms in decreasing order
MYCN_DNTP53_vs_EMPTY_signif = MYCN_DNTP53_vs_EMPTY_signif[order(MYCN_DNTP53_vs_EMPTY_signif$log2FoldChange, decreasing = T),]
#Create DEG subset containing top 10 terms in both directions
MYCN_DNTP53_vs_EMPTY_subset = rbind(head(MYCN_DNTP53_vs_EMPTY_signif, n = 10), tail(MYCN_DNTP53_vs_EMPTY_signif, n = 10))
#Filter the merged bulk for interesting samples with the genes contained in the DEG subset
Bulk_RNA_vst_MYCN_DNTP53_Empty = Bulk_RNA_vst_MYCN_DNTP53_Empty[rownames(Bulk_RNA_vst_MYCN_DNTP53_Empty)%in% MYCN_DNTP53_vs_EMPTY_subset$X,]
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "top10_DEG_MYCN_DNTP53.pdf"), width = 7.5, height = 7.5)
pheatmap(Bulk_RNA_vst_MYCN_DNTP53_Empty, cluster_row = T, scale = "row",fontsize = 15)
dev.off()
#MYCN-DTP53-GLI2_vs_EMPTY
#LFC shrinkage with apeglm
resLFC <- lfcShrink(dds, coef="condition_MYCN.DNTP53.GLI2_vs_EMPTY", type="apeglm")
#Get full DEG list
MYCN_DNTP53_GLI2_vs_EMPTY = as.data.frame(resLFC)
#Filter significant terms for exporting 
MYCN_DNTP53_GLI2_vs_EMPTY_signif = MYCN_DNTP53_GLI2_vs_EMPTY[MYCN_DNTP53_GLI2_vs_EMPTY$padj<=0.05,]
MYCN_DNTP53_GLI2_vs_EMPTY_signif = na.omit(MYCN_DNTP53_GLI2_vs_EMPTY_signif)
write.csv2(MYCN_DNTP53_GLI2_vs_EMPTY_signif, "/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/MYCN_DNTP53_GLI2_vs_EMPTY.csv")
#Visualize the results via volcano plot
MYCN_DNTP53_GLI2_vs_EMPTY$gene = rownames(MYCN_DNTP53_GLI2_vs_EMPTY)
#Add colors
MYCN_DNTP53_GLI2_vs_EMPTY$cols = ifelse(MYCN_DNTP53_GLI2_vs_EMPTY$log2FoldChange> 0.75 & MYCN_DNTP53_GLI2_vs_EMPTY$padj<=0.05, "upregulated", 
                     ifelse(MYCN_DNTP53_GLI2_vs_EMPTY$log2FoldChange< -0.75 & MYCN_DNTP53_GLI2_vs_EMPTY$padj<=0.05, "downregulated", "ns"))
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "MYCN_DNTP53_GLI2_Volcano.pdf"), width = 7.5, height = 7.5)
ggplot(MYCN_DNTP53_GLI2_vs_EMPTY, aes(x= MYCN_DNTP53_GLI2_vs_EMPTY$log2FoldChange, y = -log10(MYCN_DNTP53_GLI2_vs_EMPTY$padj), colour = MYCN_DNTP53_GLI2_vs_EMPTY$cols))+
    geom_point(aes(size = 2.5))+
    #geom_text_repel(label = MYCN_DNTP53_GLI2_vs_EMPTY$label, nudge_y = 0.1, colour = "black", box.padding = 0.3, point.padding = 0.2, direction = "both")+
    xlim(-10,10)+
    ylim(0,max(MYCN_DNTP53_GLI2_vs_EMPTY$padj)+1)+
    geom_hline(yintercept = 1.3, linetype = "dashed")+
    geom_vline(xintercept = c(-0.75, +0.75), linetype = "dashed")+
    theme_bw()+
    xlab("Log2FoldChange")+
    ylab("Significance")+
    theme(axis.text.x = element_text(size = 20),
          axis.text.y = element_text(size = 20),
          axis.title.x = element_text(size = 25),
          axis.title.y = element_text(size = 25),
          legend.position = 'none')+
    scale_colour_manual(values = c("downregulated" = "navyblue",
                          "upregulated" = "darkred",
                          "ns" = "gray")) +
    annotate("text", x = -Inf, y = Inf, label = "Empty cag",
           hjust = -0.1, vjust = 1.1, size = 7.5, color = "navyblue")+
    annotate("text", x = Inf, y = Inf, label = "MYCN, DNTP53 and GLI2",
           hjust = 1.1, vjust = 1.1, size = 7.5, color = "darkred")
dev.off()
#Visualize top 20 DEG (don't forget to normalise the counts)
dds_vst = vst(dds, blind=FALSE)
Bulk_RNA_vst = as.data.frame(assay(dds_vst))
#Filter for samples of interest
Bulk_RNA_vst_MYCN_DNTP53_GLI2_Empty = Bulk_RNA_vst[,c("CB2402.03.mix.6.MYCN.DNTP53.GLI2","CB2402.03.mix.8.empty.cag.ig","CB2410.11.mix.6.MYCN.DNTP53.GLI2","CB2410.11.mix.8.empty.cag.ig","CB2412.13.mix.6.MYCN.DNTP53.GLI2","CB2412.13.mix.8.empty.cag.ig"),]
#Filter for genes of interest (we use the top10 DEG in both direction)
MYCN_DNTP53_GLI2_vs_EMPTY_signif = read.csv2("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/MYCN_DNTP53_GLI2_vs_EMPTY.csv")
#Order terms in decreasing order
MYCN_DNTP53_GLI2_vs_EMPTY_signif = MYCN_DNTP53_GLI2_vs_EMPTY_signif[order(MYCN_DNTP53_GLI2_vs_EMPTY_signif$log2FoldChange, decreasing = T),]
#Create DEG subset containing top 10 terms in both directions
MYCN_DNTP53_GLI2_vs_EMPTY_subset = rbind(head(MYCN_DNTP53_GLI2_vs_EMPTY_signif, n = 10), tail(MYCN_DNTP53_GLI2_vs_EMPTY_signif, n = 10))
#Filter the merged bulk for interesting samples with the genes contained in the DEG subset
Bulk_RNA_vst_MYCN_DNTP53_GLI2_Empty = Bulk_RNA_vst_MYCN_DNTP53_GLI2_Empty[rownames(Bulk_RNA_vst_MYCN_DNTP53_GLI2_Empty)%in% MYCN_DNTP53_GLI2_vs_EMPTY_subset$X,]
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "top10_DEG_MYCN_DNTP53_GLI2.pdf"), width = 7.5, height = 8)
pheatmap(Bulk_RNA_vst_MYCN_DNTP53_GLI2_Empty, cluster_row = T, scale = "row",fontsize = 15)
dev.off()

##Analyze MYCN-DTP53 vs MYCN-DNTP53-GLI2
#Set reference to MYCN-DNTP53 - this will set up the analysis against the empty group
design$condition = relevel(design$condition, ref = "MYCN-DNTP53")
rownames(design) = colnames(Bulk_RNA_merge)
dds <- DESeqDataSetFromMatrix(countData = Bulk_RNA_merge,
                              colData = design,
                              design = ~ condition)
##QC the dds object
smallestGroupSize <- 3
retain <- rowSums(counts(dds) >= 10) >= smallestGroupSize
dds <- dds[retain,]
##Differentially Expressed Gene Analysis with apeglm shrinkage of fold changes
dds <- DESeq(dds)
resultsNames(dds)
#LFC shrinkage with apeglm
resLFC <- lfcShrink(dds, coef="condition_MYCN.DNTP53.GLI2_vs_MYCN.DNTP53", type="apeglm")
#Get the full DEG list
MYCN_DNTP53_GLI2_vs_MYCN.DNTP53 = as.data.frame(resLFC)
#Filter significant terms for exporting 
MYCN_DNTP53_GLI2_vs_MYCN.DNTP53_signif = MYCN_DNTP53_GLI2_vs_MYCN.DNTP53[MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$padj<=0.05,]
MYCN_DNTP53_GLI2_vs_MYCN.DNTP53_signif = na.omit(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53_signif)
write.csv2(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53_signif, "/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/MYCN_DNTP53_GLI2_vs_MYCN.DNTP53.csv")
#Visualize the results via volcano plot
MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$gene = rownames(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53)
#Add colors
MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$cols = ifelse(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$log2FoldChange> 0.75 & MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$padj<=0.05, "upregulated", 
                     ifelse(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$log2FoldChange< -0.75 & MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$padj<=0.05, "downregulated", "ns"))
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "MYCN_DNTP53_GLI2_vs_MYCN_DNTP53_Volcano.pdf"), width = 7.5, height = 7.5)
ggplot(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53, aes(x= MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$log2FoldChange, y = -log10(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$padj), colour = MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$cols))+
    geom_point(aes(size = 2.5))+
    xlim(-10,10)+
    ylim(0,max(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53$padj)+1)+
    geom_hline(yintercept = 1.3, linetype = "dashed")+
    geom_vline(xintercept = c(-0.75, +0.75), linetype = "dashed")+
    theme_bw()+
    xlab("Log2FoldChange")+
    ylab("Significance")+
    theme(axis.text.x = element_text(size = 20),
          axis.text.y = element_text(size = 20),
          axis.title.x = element_text(size = 25),
          axis.title.y = element_text(size = 25),
          legend.position = 'none')+
    scale_colour_manual(values = c("downregulated" = "navyblue",
                          "upregulated" = "darkred",
                          "ns" = "gray")) +
    annotate("text", x = -Inf, y = Inf, label = "MYCN, TP53",
           hjust = -0.1, vjust = 1.1, size = 5, color = "navyblue")+
    annotate("text", x = Inf, y = Inf, label = "MYCN, DNTP53\n and GLI2",
           hjust = 1.1, vjust = 1.1, size = 5, color = "darkred")
dev.off()
#Visualize top 20 DEG (don't forget to normalise the counts)
dds_vst = vst(dds, blind=FALSE)
Bulk_RNA_vst = as.data.frame(assay(dds_vst))
#Filter for samples of interest
Bulk_RNA_vst_MDvsMDG = Bulk_RNA_vst[,c("CB2402.03.mix.2.MYCN.DNTP53","CB2402.03.mix.6.MYCN.DNTP53.GLI2","CB2410.11.mix.2.MYCN.DNTP53","CB2410.11.mix.6.MYCN.DNTP53.GLI2","CB2412.13.mix.2.MYCN.DNTP53","CB2412.13.mix.6.MYCN.DNTP53.GLI2")]
#Filter for genes of interest (we use the top10 DEG in both direction)
MYCN_DNTP53_GLI2_vs_MYCN.DNTP53_signif = read.csv2("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/MYCN_DNTP53_GLI2_vs_MYCN.DNTP53.csv")
#Order terms in decreasing order
MYCN_DNTP53_GLI2_vs_MYCN.DNTP53_signif = MYCN_DNTP53_GLI2_vs_MYCN.DNTP53_signif[order(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53_signif$log2FoldChange, decreasing = T),]
#Create DEG subset containing top 10 terms in both directions
Bulk_RNA_vst_MDvsMDG_subset = rbind(head(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53_signif, n = 50), tail(MYCN_DNTP53_GLI2_vs_MYCN.DNTP53_signif, n = 50))
#Filter the merged bulk for interesting samples with the genes contained in the DEG subset
Bulk_RNA_vst_MDvsMDG = Bulk_RNA_vst_MDvsMDG[rownames(Bulk_RNA_vst_MDvsMDG)%in% Bulk_RNA_vst_MDvsMDG_subset$X,]
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "top10_DEG_MYCN_DNTP53_GLI2vsMYCN_DNTP53.pdf"), width = 7.5, height = 8)
annotation = data.frame(rep(c("MYCN_DNTP53", "MYCN_DNTP53_GLI2"), times=3))
rownames(annotation) = colnames(Bulk_RNA_vst_MDvsMDG)
colnames(annotation) = "Groups"
annotation_colors = list(Groups= c("MYCN_DNTP53" = "navyblue", "MYCN_DNTP53_GLI2" = "darkred"))
pheatmap(Bulk_RNA_vst_MDvsMDG, cluster_row = T, scale = "row",fontsize = 15, show_colnames=F, show_rownames=F, annotation = annotation, annotation_colors = annotation_colors)
dev.off()

#Visualization of normalised counts for induced genes in the single bulk RNA runs
dds_vst = vst(dds, blind=FALSE)
Bulk_RNA_vst = assay(dds_vst)
write.csv2(Bulk_RNA_vst, "/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/Bulk_RNA_merge_vst_Normalized.csv")
#Heatmap - subset all the GOI together and plot
Bulk_RNA_merge_subset = Bulk_RNA_vst[rownames(Bulk_RNA_vst) %in% c("MYCN", "TP53", "GLI2"),]
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "Heatmap_NormCounts.pdf"), width = 7.5, height = 5)
pheatmap(Bulk_RNA_merge_subset, scale = "none", cluster_row = F, cluster_cols = T)
dev.off()
#Boxplot_MYCN
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "MYCN_NormCounts_Box.pdf"), width = 5, height = 5)
#Subset GOI singularly
Bulk_RNA_merge_subset = Bulk_RNA_vst[rownames(Bulk_RNA_vst) %in% "MYCN",]
Bulk_RNA_merge_subset_melt = reshape2::melt(Bulk_RNA_merge_subset)
Bulk_RNA_merge_subset_melt$grouping = c(#"MYCN", 
                                        "MYCN_DNTP53", 
                                        "MYCN_DNTP53_GLI2", 
                                        "EMPTY",
                                        #"MYCN", 
                                        "MYCN_DNTP53", 
                                        "MYCN_DNTP53_GLI2", 
                                        "EMPTY",
                                        "MYCN_DNTP53", 
                                        "MYCN_DNTP53_GLI2", 
                                        "EMPTY")
ggplot(Bulk_RNA_merge_subset_melt, aes(x = Bulk_RNA_merge_subset_melt$grouping, y = Bulk_RNA_merge_subset_melt$value))+
    geom_boxplot(aes(fill = Bulk_RNA_merge_subset_melt$grouping))+
    geom_jitter(width = 0, size = 2.5)+
    theme_bw()+
    ggtitle("MYCN Expression")+
    ylab("Normalized counts")+
    xlab("")+
    theme(axis.text.x = element_text(size = 10, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 10),
          title = element_text(size = 10),
          legend.title=element_blank())
dev.off()
#Boxplot_TP53
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "TP53_NormCounts_Box.pdf"), width = 5, height = 5)
#Subset GOI singularly
Bulk_RNA_merge_subset = Bulk_RNA_vst[rownames(Bulk_RNA_vst) %in% "TP53",]
Bulk_RNA_merge_subset_melt = reshape2::melt(Bulk_RNA_merge_subset)
Bulk_RNA_merge_subset_melt$grouping = c(#"MYCN", 
                                        "MYCN_DNTP53", 
                                        "MYCN_DNTP53_GLI2", 
                                        "EMPTY",
                                        #"MYCN", 
                                        "MYCN_DNTP53", 
                                        "MYCN_DNTP53_GLI2", 
                                        "EMPTY",
                                        "MYCN_DNTP53", 
                                        "MYCN_DNTP53_GLI2", 
                                        "EMPTY")
ggplot(Bulk_RNA_merge_subset_melt, aes(x = Bulk_RNA_merge_subset_melt$grouping, y = Bulk_RNA_merge_subset_melt$value))+
    geom_boxplot(aes(fill = Bulk_RNA_merge_subset_melt$grouping))+
    geom_jitter(width = 0, size = 2.5)+
    theme_bw()+
    ggtitle("TP53 Expression")+
    ylab("Normalized counts")+
    xlab("")+
    theme(axis.text.x = element_text(size = 10, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 10),
          title = element_text(size = 10),
          legend.title=element_blank())
dev.off()
#Boxplot_GLI2
pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "GLI2_NormCounts_Box.pdf"), width = 5, height = 5)
#Subset GOI singularly
Bulk_RNA_merge_subset = Bulk_RNA_vst[rownames(Bulk_RNA_vst) %in% "GLI2",]
Bulk_RNA_merge_subset_melt = reshape2::melt(Bulk_RNA_merge_subset)
Bulk_RNA_merge_subset_melt$grouping = c(#"MYCN", 
                                        "MYCN_DNTP53", 
                                        "MYCN_DNTP53_GLI2", 
                                        "EMPTY",
                                        #"MYCN", 
                                        "MYCN_DNTP53", 
                                        "MYCN_DNTP53_GLI2", 
                                        "EMPTY",
                                        "MYCN_DNTP53", 
                                        "MYCN_DNTP53_GLI2", 
                                        "EMPTY")
ggplot(Bulk_RNA_merge_subset_melt, aes(x = Bulk_RNA_merge_subset_melt$grouping, y = Bulk_RNA_merge_subset_melt$value))+
    geom_boxplot(aes(fill = Bulk_RNA_merge_subset_melt$grouping))+
    geom_jitter(width = 0, size = 2.5)+
    theme_bw()+
    ggtitle("GLI2 Expression")+
    ylab("Normalized counts")+
    xlab("")+
    theme(axis.text.x = element_text(size = 10, angle = 45, hjust = 1),
          axis.text.y = element_text(size = 10),
          title = element_text(size = 10),
          legend.title=element_blank())
dev.off()

pdf(paste0("/hpc/pmc_kool/fvalzano/Rstudio_Test1/Cerebellum_Development/DESEQ2_Analysis/DESeq2_MYCN_MYCN-DNTP53_MYCN-DNTP53-GLI2/Plots/", Plotting_directory, "PCA.pdf"), width = 7.5, height = 7.5)
design = data.frame(condition = factor(c(#"MYCN", 
                         "MYCN-DNTP53",
                         "MYCN-DNTP53-GLI2", 
                         "EMPTY", 
                         #"MYCN", 
                         "MYCN-DNTP53",
                         "MYCN-DNTP53-GLI2", 
                         "EMPTY", 
                         "MYCN-DNTP53",
                         "MYCN-DNTP53-GLI2", 
                         "EMPTY")))
design$condition = relevel(design$condition, ref = "EMPTY")
rownames(design) = colnames(Bulk_RNA_merge)
dds <- DESeqDataSetFromMatrix(countData = Bulk_RNA_merge,
                              colData = design,
                              design = ~ condition)
dds_vst = vst(dds, blind=FALSE)
plotPCA(dds_vst, intgroup=c("condition")) +
       theme_bw()
dev.off()
