library(shiny)
library(poppr)
library(ape)
library(phangorn)
library(igraph)
library(gdata)
library(phyloch)

# Change this path to reflect where your binary of muscle is located.
muscle_dir <- "/usr/bin/muscle"
mafft_bin <- "/usr/local/bin/mafft"

query_name <- "query_isolate"

adekambi_defined_genes <- c("ftsY", "infB", "rpoB", "rsmA", "secY", "tsaD", "ychF")
rhodococcus_16S_defined_genes <- c("16S")



get_last_substring <- function(x, sep = "_"){
  splitx <- strsplit(x, sep)
  last   <- vapply(splitx, function(y) y[[length(y)]], character(1))
  return(last)
}



# Functions to reduce redundancy
## Plotting trees
plot.tree <- function (tree, type = input$tree, ...){
  ARGS <- c("nj", "upgma")
  type <- match.arg(type, ARGS)
  barlen <- min(median(tree$edge.length), 0.1)
  if (barlen < 0.1) 
    barlen <- 0.01
#  subtreeplot(tree, wait=TRUE)
  plot.phylo(tree, type = "phylogram", cex = 0.8, font = 2, adj = 0, xpd = TRUE, 
             label.offset = 0, ...)
  nodelabels(tree$node.label, adj = c(1.3, -0.5), frame = "n", 
             cex = 0.8, font = 3, xpd = TRUE)
  if (type == "nj") {
    add.scale.bar(lwd = 5, length = barlen)
    tree <- ladderize(tree)
  }
  else {
#    axisPhylo(3)
  }
}

## Plotting Minimum spanning network
plot.minspan <- function(gen, mst, gadj=3, inds="none", ...){
  plot_poppr_msn(gen, mst, gadj=gadj, vertex.label.color = "firebrick",nodelab=100,
                 vertex.label.font = 2, vertex.label.dist = 0.5, 
                 inds = inds, quantiles = FALSE)  
}

shinyServer(function(input, output, session) {

  data_f <- reactive({ 
    df <- read.dna(input$dataset, format = "fasta")
    return(df)
    })

  alin <- reactive({
    if (gsub("\\s", "", input$fasta) == ""){
      return(NULL)
    } else {
      if (startsWith(input$fasta,">") == TRUE){
		currenttime <- as.numeric(as.POSIXct(Sys.time()))
		inputfilename <- paste0("input", currenttime, ".fasta")
		cat(input$fasta, file=inputfilename)
		#cat(input$fasta, file="input.fasta")
        #input_table <- read.dna("input.fasta", format="fasta", as.matrix = FALSE)
        input_table <- read.dna(inputfilename, format="fasta", as.matrix = FALSE)
		unlink(inputfilename)
		#inputgenelist <- rownames(input_table)
		inputgenelist <- names(input_table)
		#Get user-selected MLSA gene set to use
		input_datasetname <- input$dataset
		if (input_datasetname == "adekambi-MLSA") {
			defined_genes <- adekambi_defined_genes
        } else if (input_datasetname == "rhodococcus-16S") {
			defined_genes <- rhodococcus_16S_defined_genes
        } else {
			#might as well add a default, but there should always be one selected
			defined_genes <- test_defined_genes
		}

        is_first_gene <- TRUE
		#foreach gene name
		#	check if it is in the list of our genes
		#	if it is:
		#		change sequence name to query_isolate
		#		mafft add to that genes alignment
		#		concatenate with master alignment
		for (i in inputgenelist){
			#check if the user-supplied gene name is in our list of allowed genes
			if (i %in% defined_genes){
				gene_aln_file <- paste0(i, "_RHA1.aln", "")
				gene_aln <- read.dna(gene_aln_file, format="fasta")
				#get seq for i
				#input_seq <- input_table[dimnames(input_table)[[1]]==i,]
				input_seq <- input_table[names(input_table)==i]
				names(input_seq) <- c("query_isolate")
				#rownames(input_seq) <- c("query_isolate")
				#add seq to existing gene alignment
				individual_aln <- mafft(gene_aln, input_seq, "add", "localpair", mafft_bin, quiet)
				write.dna(individual_aln, "individual1.aln", format="fasta")
				#if this is the first alignment set the result as the overall one
				if(is_first_gene){
					all.al <- individual_aln
					is_first_gene <- FALSE
				}else{
					#otherwise concatenate it with the existing alignments using phyloch's c.genes()
					temp.al <- c.genes(all.al, individual_aln)
					all.al <- temp.al
				}
				write.dna(all.al, "alltest.aln", format="fasta")
			}else{
				return(FALSE)
			}
		}		
		return(all.al)
      }else{
        return(FALSE)
      }
    }
    })
  

  dist.genoid <- reactive({
    all.dist <- dist.dna(alin(),input$model)
    return(all.dist)
  })
  
  data.genoid <- reactive({
    gen <- DNAbin2genind(alin())
    #Adding colors to the tip values according to the clonal lineage
    popnames <- get_last_substring(gen$ind.names, "_")
    pop(gen) <- popnames
    gen$other$tipcolor <- pop(gen)
    name_char_end <- nchar(indNames(gen)) - nchar(popnames) - 1
    gen$ind.names <- substr(indNames(gen), 1, name_char_end)
    gen$other$input_data <- indNames(gen)[pop(gen) %in% "query"]
    ngroups   <- length(levels(gen$other$tipcolor))
#     ########### IMPORTANT ############
#     # Change these colors to represent the groups defined in your data set.
#     #
    defined_groups <- c("black") 
	#defined_groups <- c("blue", "darkcyan", "darkolivegreen", "darkgoldenrod")
#     #
#     # Change heat.colors to whatever color palette you want to represent
#     # submitted data. 
#     #
     input_colors   <- rainbow(ngroups - length(defined_groups), v = 0)
#     #
#     ##################################
    levels(gen$other$tipcolor) <- c(defined_groups, input_colors)
     gen$other$tipcolor <- as.character(gen$other$tipcolor)
    return(gen)
  })
  
  seed <- reactive({
    return(input$seed)
  })

#Greyscale Slider  
slider <- reactive({
  slider.a <- (input$integer)
  return(slider.a)
})

  
  boottree <- reactive({
    if (input$boot > 1000){
      return(1000L)
    } else if (input$boot < 10){
      return(10L)
    }
    set.seed(seed())
      if (input$tree == "upgma"){
        tre <- upgma(dist.genoid())
        bp <- boot.phylo(tre,alin(),function(x) upgma(dist.dna(x,input$model)),B=input$boot)
      } else {
        tre <- nj(dist.genoid())
        bp <- boot.phylo(tre,alin(),function(x) nj(dist.dna(x,input$model)),B=input$boot)
      }
    tre$node.labels <- round(((bp / input$boot)*100))
    #tre$tip.label <- paste(tre$tip.label, as.character(pop(data.genoid()))) 
    if (input$tree=="nj"){
      tre <- phangorn::midpoint(ladderize(tre))
    }
    return(tre)
  })
  
  msnet <- reactive ({
    msn.plot <-poppr.msn(data.genoid(), dist.genoid(), palette=rainbow, showplot = FALSE)
    #V(msn.plot$graph)$size <- 3
    return(msn.plot)
  })

#Output

output$validateFasta <- renderText({
  if (is.null(alin())){
    return("")
  } else if (alin() == FALSE){
    return("ERROR: Invalid input, make sure sequences are in Fasta format and match gene names")
  }
  })

  output$distPlotTree <- renderPlot({
    if (is.null(alin())){
      plot.new() 
      rect(0, 1, 1, 0.8, col = "indianred2", border = 'transparent' ) + 
      text(x = 0.5, y = 0.9, "No FASTA data has been input.", cex = 1.6, col = "white")
    } else if (alin() == FALSE){
      plot.new() 
      rect(0, 1, 1, 0.8, col = "indianred2", border = 'transparent' ) + 
        text(x = 0.5, y = 0.9, "Invalid FASTA input.", cex = 1.6, col = "white")
    } else if (is.integer(boottree())){
      msg <- ifelse(boottree() > 10L, "\nless than or equal to 1000",
                                      "greater than 10")
      msg <- paste("The number of bootstrap replicates should be", msg)
      plot.new()
      rect(0, 1, 1, 0.8, col = "indianred2", border = 'transparent' ) + 
      text(x = 0.5, y = 0.9, msg, cex = 1.6, col = "white")
    } else {
      plot.tree(boottree(), type = input$tree, tip.col=as.character(unlist(data.genoid()$other$tipcolor)))
    }
  })
  
  #Minimum Spanning Network
  output$MinSpanTree <- renderPlot({
    if (is.null(alin())){
      plot.new() 
      rect(0, 1, 1, 0.8, col = "indianred2", border = 'transparent' ) + 
        text(x = 0.5, y = 0.9, "No FASTA data has been input.", cex = 1.6, col = "white")
    } else if (alin() == FALSE){
      plot.new() 
      rect(0, 1, 1, 0.8, col = "indianred2", border = 'transparent' ) + 
        text(x = 0.5, y = 0.9, "Invalid FASTA input.", cex = 1.6, col = "white")
    } else {
      #plot_poppr_msn(data.genoid(), msnet(), gadj=c(slider()), vertex.label.color = "firebrick", vertex.label.font = 2, vertex.label.dist = 0.5,                    inds = data.genoid()$other$input_data.genoid, quantiles = FALSE)  
      plot.minspan(data.genoid(), msnet(), gadj=c(slider()), ind = data.genoid()$other$input_data)
    }
  })
    
  output$downloadData <- downloadHandler(
    filename = function() { paste0(input$tree, '.tre') },
    content = function(file) {
      write.tree(boottree(), file)
    })
  
  output$downloadPdf <- downloadHandler(
    filename = function() { paste0(input$tree, '.pdf') },
    content = function(file) {
      pdf(file, width=11, height=8.5)
      plot.tree(boottree(), type = input$tree, tip.col=as.character(unlist(data.genoid()$other$tipcolor)))
      dev.off()
    })
  
  output$downloadPdfMst <- downloadHandler(
    filename = function() { paste0("min_span_net", '.pdf')} ,
    content = function(file) {
      pdf(file, width=11, height=8.5)
      set.seed(seed())
      plot.minspan(data.genoid(), msnet(), gadj=c(slider()), ind = data.genoid()$other$input_data)
      dev.off()
    })
  
})
