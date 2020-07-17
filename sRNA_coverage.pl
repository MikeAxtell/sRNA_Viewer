#!/usr/bin/perl
use Getopt::Std;
getopts('hvb:c:');
$version = 0.5;
$usage = "sRNA_coverage.pl version $version

USAGE: sRNA_coverage.pl -b bam_file_list.txt -c chr:start-stop

INPUT: Plain-text file containing filepaths to one or more BAM files that
       each have been processed by add_YS.pl and indexed.

REQUIRES: samtools

OUTPUT: Tab-delimited table of coverage values from the specified interval that
can be used for plotting. Table is sent to STDOUT.";

if($opt_v) {
    die "sRNA_coverage.pl version $opt_v\n";
}

if($opt_h) {
    die "$usage\n";
}

unless($opt_b and $opt_c) {
    die "$usage";
}

# check for file list
unless(-r $opt_b) {
    die "Could not read bam file list; check -b \n\n$usage\n";
}

# parse bamfile list, check readability and presence of .bai indices, and check for YS tags.
open(FILES, "$opt_b");
@bam_files = <FILES>;
close FILES;
foreach $bam_file (@bam_files) {
    $bam_file =~ s/\r//g;
    $bam_file =~ s/\n//g;
    unless(-r $bam_file) {
        die "bam file $bam_file was not readable!\n\n";
    }
    $baifile = $bam_file . '.bai';
    unless(-r $baifile) {
        die "Could not find the bam file index for $bam_file. Please index the bamfile before trying again.\n";
    }
    # examine the first alignment in the file quickly, to ensure it has a YS tag.
    open(SAM, "samtools view $bam_file | head -n 1 |");
    $testline = <SAM>;
    close SAM;
    unless($testline =~ /\tYS:Z:/) {
        die "No YS tags found in bam file $bam_file . Please process this and all bam files with add_YS.pl before using this script.\n\n$usage\n";
    }
}

# parse out start and stop
if($opt_c =~ /^(\S+):(\d+)-(\d+)$/) {
    $chromosome = $1;
    $start = $2;
    $stop = $3;
} else {
    die "Could not parse the requested position. Check -c \n";
}

# column names
print "Chromosome\tPosition\tRaw_Depth\tRPM_Depth\tSize_Category\tStrand\tBAM_File\n";

# Arrays holding information needed for each loop
@YS = ('YS:\<21nts', 'YS:\<21nts',
       'YS:21nts', 'YS:21nts',
       'YS:22nts', 'YS:22nts',
       'YS:23-24nts', 'YS:23-24nts',
       'YS:\>24nts', 'YS:\>24nts');
@fs = ('-F 16', '-f 16',
       '-F 16', '-f 16',
       '-F 16', '-f 16',
       '-F 16', '-f 16',
       '-F 16', '-f 16');
@signs = ('+', '-',
          '+', '-',
          '+', '-',
          '+', '-',
          '+', '-');
@YS2 = ('<21nts', '<21nts',
        '21nts', '21nts',
        '22nts', '22nts',
        '23-24nts', '23-24nts',
        '>24nts', '>24nts');

# Loop through each bam file
foreach $bam_file (@bam_files) {
    $bam_file =~ s/\r//g;
    $bam_file =~ s/\n//g;
    
    # Strip off leading directories and .bam extension for the output
    $bam_short = $bam_file;
    $bam_short =~ s/^.*\///;
    $bam_short =~ s/\.bam$//;

    # Rapidly get total primary reads in file
    $awkcmd = '\'{s+=$1} END {printf "%.0f", s}\'';
    open(COUNT, "samtools idxstats $bam_file | cut -f 3 | awk $awkcmd |");
    $count = <COUNT>;
    close COUNT;
    chomp $count;
    $Mcount = $count / 1E6;

    # Get depths for strand & category
    for($i = 0; $i < 10; ++$i) {
        $got_start = 0;
        $got_stop = 0;
        open(DEPTH, "samtools view -b -d $YS[$i] $fs[$i] $bam_file $opt_c | samtools depth -d 0 - |");
        while (<DEPTH>) {
            chomp;
            @f = split("\t", $_ );  ## f[1] is coordinate
            $got_one = 1;
            if($f[1] == $start) {
                $got_start = 1;
            }
            if($f[1] == $stop) {
                $got_stop = 1;
            }
            $rpm = sprintf("%.2f", $f[2] / $Mcount);
            print $_ . "\t$rpm\t" . $YS2[$i] . "\t" . $signs[$i] . "\t$bam_short\n";
        }
        close DEPTH;
        
        # Add zero lines if needed. Each category needs a line at the start and stop, minimally.
        #  this is required for proper plotting by sRNA_Viewer.R
        unless($got_start) {
            print "$chromosome\t$start\t0\t0.00\t$YS2[$i]\t$signs[$i]\t$bam_short\n";
        }
        unless($got_stop) {
            print "$chromosome\t$stop\t0\t0.00\t$YS2[$i]\t$signs[$i]\t$bam_short\n";
        }
    }
}
