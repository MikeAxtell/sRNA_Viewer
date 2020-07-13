#!/usr/bin/perl 

use Getopt::Std;
getopts('hvb:F:');
$version = 0.2;
$help = "add_YS.pl version $version\n";
$help .= '
Add YS tags, indicating small RNA read length classes, to BAM file.

USAGE: add_YS.pl -b bamfile -F filterFLAG 

OPTIONS:
-h : show this message
-v : print version
-b : path to indexed BAM file. (Required).
-F : SAM FLAGs to filter out during processing. Defaults to 256 (ignores
     secondary alignments) if not specified.

DEPENDENCIES:
samtools (in PATH)
indexed, sorted BAM file for input (option -b)

OUTPUT:
Writes a new bamfile with YS tags for all alignments.

';
if($opt_v) {
	print "add_YS.pl version $version\n";
	exit;
}
if($opt_h) {
	print $help;
	exit;
}
unless(-r $opt_b) {
	print STDERR "BAM file from -b not readable.\n";
	print STDERR $help;
	exit;
}
unless($opt_F) {
	$opt_F = 256;
}
$outBAM = $opt_b;
$outBAM =~ s/\.bam$/_YS\.bam/;

# add a custum YS tag to a bam file.
# YS is for small RNA size class.
# Size classes are < 21nts, 21nts, 22nts, 23-24nts, and >24nts.
# adding this tag makes it easier to view sRNA-seq alignments in IGV (color by YS, group by YS, etc.)
open(IN, "samtools view -h -F $opt_F $opt_b |");
open(OUT, "| samtools view -b - > $outBAM");
$head = 1;
while (<IN>) {
	if($_ =~ /^\@/) {
		print OUT $_;
	} else {
		if ($head == 1) {
			print OUT "\@PG\tID:add_YS\tPN:add_YS\n";
			$head = 0;
		}
		chomp;
		# The only reliable way to infer the length of SEQ is
		#  via the CIGAR string. Sum of X/S/I/M/= operations.
		#  The SEQ field itself is technically optional.
		# CIGAR is column 5 in zero-based
		@f = split ("\t", $_);
		$cigar = $f[5];
		$len = 0;
		while($cigar =~ /(\d+)[MSIX\=]/g) {
			$len += $1;
		}
		if($len < 21) {
			$YS = '<21nts';
		} elsif ($len == 21) {
			$YS = '21nts';
		} elsif ($len == 22) {
			$YS = '22nts';
		} elsif ($len == 23 or $len == 24) {
			$YS = '23-24nts';
		} else {
			$YS = '>24nts';
		}
		print OUT "$_" . "\tYS:Z:$YS\n";
	}
}
close(IN);
close(OUT);
exit;
