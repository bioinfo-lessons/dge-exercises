library("airway")
library("DESeq2")
library("pheatmap")
library("RColorBrewer")

## Cargamos nuestro dataset de ejemplo
data("airway")

summarized_experiment <- airway

## Vamos a explorar el colData, es decir, la info. experimental
exp_info <- as.data.frame(summarized_experiment@colData)
    
## Creamos el objeto DESeq2
dds <- DESeqDataSet(summarized_experiment, design = ~cell + dex)

## Prefiltrado. Vamos a eliminar genes
## con tan poquitas cuentas que no merece la pena conservar.
## Así ahorramos memoria, aunque no ganamos nada a efectos estadísticos.
keep <- rowSums(counts(dds)) >= 10 ## Seleccionar genes con más de 10 cuentas en todos los samples
dds <- dds[keep, ]

## Antes de hacer la DGE, hagamos un análisis exploratorio
## la función VST normaliza y estabiliza la varianza de las counts. Ideal para
## clustering o PCA.

## La diferencia entre VST y la función DESeq radica en que la expresión diferencial
## no usa las cuentas normalizadas (y estabilizadas) per sé, sino que los factores de 
## normalización y dispersión se incluyen en un modelo BN con las cuentas crudas.
## Para visualización, clustering etc. la función vst transforma las counts y estabiliza
## la varianza APARTE para que podamos trabajar con cuentas ya "listas".

vsd <- vst(dds, blind = TRUE)
plotPCA(vsd, intgroup = "cell")
plotPCA(vsd, intgroup = "dex")

## Calculamos las distancias a partir de las cuentas normalizadas y variance-stabilized (vst)
sampleDists <- dist(t(assay(vsd)))

sampleDistMatrix <- as.matrix(sampleDists)
rownames(sampleDistMatrix) <- paste(vsd$cell, vsd$dex, sep="-")
colnames(sampleDistMatrix) <- NULL
colors <- colorRampPalette( rev(brewer.pal(9, "Blues")) )(255)
pheatmap(sampleDistMatrix,
         clustering_distance_rows=sampleDists,
         clustering_distance_cols=sampleDists,
         col=colors)


## Nos preparamos para la DGE haciendo el modelo lineal a partir de la BN
## La función DESeq realiza todos los pasos de DESeq2 desde estimar los size factors
## hasta controla la dispersión
dds2 <- DESeq(dds, test = "Wald")

## Vamos a verificar cómo ha quedado la estimación de la dispersión 
plotDispEsts(dds2)

## Exploremos cómo quedan los cambios de fold entre condiciones con respecto
## a las cuentas normalizadas
plotMA(dds2)

## Obtengamos nuestra lista de genes DEG
my_results <- results(object = dds2,
                      contrast = c("dex", "trt", "untrt"),
                      alpha = 0.05,
                      pAdjustMethod = "BH",
                      tidy = TRUE
                      )

## Suele ser buena idea establecer un corte a priori de log fold
my_results_threshold <- results(object = dds2,
                                contrast = c("dex", "trt", "untrt"),
                                lfcThreshold = 1,
                                alpha = 0.05,
                                pAdjustMethod = "BH",
                                tidy = TRUE
                                )

## Heatmap de los genes TOP DGE por p-valor ajustado
mat <- assay(vsd)[head(order(my_results_threshold$padj), 30), ] 
pheatmap(mat)
