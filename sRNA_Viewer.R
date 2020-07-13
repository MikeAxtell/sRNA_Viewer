#!/usr/bin/env Rscript --vanilla

# Set PATH because at least on my system stupid Rscript invocation can't even find rm,
#  leading to harmless but annoying error message when script ends.
#  This should fix it on most systems.
Sys.setenv(PATH = '/usr/local/bin:/usr/bin:/bin:/usr/sbin')

# Load required libraries, quietly
library(docopt)
suppressPackageStartupMessages(library(tidyverse))
suppressPackageStartupMessages(library(cowplot))

# Define options and documentation
"sRNA_Viewer.R

Usage:
  sRNA_Viewer.R ([-] | -c COVFILE) -p OUTPUTFILE
  sRNA_Viewer.R -h | --help
  sRNA_Viewer.R -v | --version

Options:
  -h --help      # Print this message and quit
  -v --version   # Print version number and quit
  -c COVFILE     # Input file of coverage data produced by sRNA_coverage.pl
  [-]            # COVFILE can alternatively be received through STDIN (e.g. from a pipe)
  -p OUTPUTFILE  # Output PDF file

" -> doc

opts <- docopt(doc,
               version='0.1')


## Command-line parsing .
pdf_file = opts$p

## Determine if the table is coming through STDIN or from a regular file
if(is.null(opts$c)) {
  coverage <- read_tsv(file("stdin"),
                     col_types = cols())
} else {
  covFile = opts$c
  coverage <- read_tsv(covFile,
                       col_types = cols())
}

# testing
#coverage <- read_tsv("~/Desktop/sRNA_Viewer/testcov.tsv")
#pdf_file = 'test.pdf'
#chr_name = 'Cp_v0.1_Contig187649'

# define color pallette
sRNAcols = c("lightgray", # <21nts
             "blue",      # 21nts
             "mediumseagreen", # 22nts
             "tomato",    # 23-24nts
             "darkgray")  # >24nts

# define the order to list the Length categories
Lorder = c("<21nts","21nts","22nts","23-24nts",">24nts")

# Get the BAM_file names
BAM_file_names <- distinct(coverage, BAM_File)
BAM_file_names <- as.vector(BAM_file_names$BAM_File)

# Get the Chromosome name
chr_name = coverage$Chromosome[1]

# Determine the y-axis limits. First, determine the maximum and minimum for each
#  BAM file
a_maxes <- vector("numeric", length = length(BAM_file_names))
a_mins <- vector("numeric", length = length(BAM_file_names))
for(i in 1:length(BAM_file_names)) {
  plus_sum <- coverage %>%
    filter(Strand == '+' & BAM_File == BAM_file_names[i]) %>%
    group_by(Position) %>%
    summarize(psum = sum(RPM_Depth), .groups="keep")
  a_maxes[i] <- max(plus_sum$psum)

  minus_sum <- coverage %>%
    filter(Strand == '-' & BAM_File == BAM_file_names[i]) %>%
    group_by(Position) %>%
    summarize(msum = -sum(RPM_Depth), .groups="keep")
  a_mins[i] <- min(minus_sum$msum)
}
# From that, get the highest max and the lowest min
actual_max = max(a_maxes)
actual_min= min(a_mins)

# Then, add a small buffer
if(actual_max == 0 & actual_min == 0) {
  # pathological case of no reads
  my_max <- 1
  my_min <- -1
} else {
  my_max = 1.05 * actual_max
  my_min = 1.05 * actual_min
}

# Make a list to hold the plots created during the upcoming loop
plots <- vector("list", length(BAM_file_names))

# Loop through each BAM file, storing plots
for(i in 1:length(BAM_file_names)) {
  # get the plus and minus sets
  cov_plus <- filter(coverage, Strand == '+' & BAM_File == BAM_file_names[i])
  cov_minus <- filter(coverage, Strand == '-' & BAM_File == BAM_file_names[i])
  
  # plot
  plots[[i]] <- ggplot() +
    geom_col(data=cov_plus,
             aes(x=Position,
                 y=RPM_Depth,
                 fill=factor(Size_Category,levels=Lorder)
             ),
             width=1) +
    geom_col(data=cov_minus,
             aes(x=Position,
                 y=-RPM_Depth,
                 fill=factor(Size_Category, levels=Lorder)
             ),
             width=1) +
    scale_fill_manual(values=sRNAcols) +
    theme_minimal() +
    ylim(my_min, my_max) +
    labs(fill="RNA Length",
         title=BAM_file_names[i],
         y="Depth of coverage (rpm)",
         x=paste0("Position in ", chr_name, " (bp)"))
}
# Set height of image, based on number of BAM files
pdf_h = length(BAM_file_names) * 2.5
# Write plots
pdf(file=pdf_file,
    height = pdf_h)
plot_grid(plotlist = plots,
          ncol = 1)
invisible(dev.off())
