#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::Diff;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);


##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION = "0.01";

##-- program vars
our $progname     = basename($0);
our $verbose      = 1;

our $outfile      = '-';
our %diffargs     = qw();

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   'man|m'  => \$man,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'output|o=s' => \$outfile,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>1}) if ($man);
#pod2usage({-exitval=>0,-verbose=>1,-msg=>'Not enough arguments specified!'}) if (@ARGV < 2);

if ($version || $verbose >= 2) {
  print STDERR "$progname version $VERSION by Bryan Jurish\n";
  exit 0 if ($version);
}

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
our $diff = Lingua::TT::Diff->new(%diffargs);

push(@ARGV,'-') if (!@ARGV);
our $outfh = IO::File->new(">$outfile")
  or die("$0: open failed for output file '$outfile': $!");

foreach $dfile (@ARGV) {
  our $dfile = shift(@ARGV);
  $diff->reset;
  $diff->loadTextFile($dfile)
    or die("$0: load failed for '$dfile': $!");

  ##-- vars
  my ($file1,$file2,$seq1,$seq2,$hunks) = @$diff{qw(file1 file2 seq1 seq2 hunks)};

  ##-- counts
  my $nseq1  = scalar(@$seq1);
  my $nseq2  = scalar(@$seq2);
  my $nhunks = scalar(@$hunks);
  my $ndel   = scalar(grep {$_->[0] eq 'd'} @$hunks);
  my $nins   = scalar(grep {$_->[0] eq 'a'} @$hunks);
  my $nchg   = scalar(grep {$_->[0] eq 'c'} @$hunks);

  ##-- formatting stuff
  my $llen  = 12;
  my $ilen1 = length($nseq1);
  my $ilen2 = length($nseq2);
  my $flen  = 5;
  my $npad  = 5;
  ##
  my $clen1 = length($file1) > ($ilen1+$flen+$npad) ? length($file1) : ($ilen1+$flen+$npad);
  my $clen2 = length($file2) > ($ilen2+$flen+$npad) ? length($file2) : ($ilen2+$flen+$npad);
  ##
  my $lfmt  = '%'.(-$llen).'s';
  my $sfmt1 = "%${clen1}s";
  my $sfmt2 = "%${clen2}s";
  my $ifmt1 = '%'.($clen1-$flen-$npad).'d';
  my $ifmt2 = '%'.($clen2-$flen-$npad).'d';
  my $ifmt1a = $ifmt1.(' ' x ($flen+$npad));
  my $ifmt2a = $ifmt2.(' ' x ($flen+$npad));
  my $ffmt  = "(%${flen}.1f %%)";
  my $iffmt  = $ifmt1.' '.$ffmt.' | '.$ifmt2.' '.$ffmt;
  my $iffmt1 = $ifmt1.' '.$ffmt.' | '.(' ' x $clen2);
  my $iffmt2 = (' ' x $clen1)  .' | '.$ifmt2.' '.$ffmt;

  ##-- report
  $outfh->print(#"DIFF: $dfile\n",
		sprintf("$lfmt: %s\n", 'Diff', $dfile),
		sprintf("$lfmt: $sfmt1 | $sfmt2\n", ' + Files', $file1, $file2),
		sprintf("$lfmt: $iffmt\n", ' + Items', $nseq1, 100, $nseq2, 100),
		sprintf("$lfmt: $iffmt\n", ' + Hunks', $nhunks, 100*$nhunks/$nseq1, $nhunks, 100*$nhunks/$nseq2),
		sprintf("$lfmt: $iffmt1\n", '   - DELETE', $ndel, 100*$ndel/$nseq1),
		sprintf("$lfmt: $iffmt2\n", '   - INSERT', $nins, 100*$nins/$nseq2),
		sprintf("$lfmt: $iffmt\n",  '   - CHANGE',  $nchg, 100*$nchg/$nseq1, $nchg, 100*$nchg/$nseq2),
	       );
}

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-diff-info.perl - get basic info from tt-diff files

=head1 SYNOPSIS

 tt-diff-info.perl OPTIONS [TTFILE(s)]

 General Options:
   -help
   -version
   -verbose LEVEL

 Other Options:
   -output FILE         ##-- output file (default: STDOUT)

=cut

###############################################################
## OPTIONS
###############################################################
=pod

=head1 OPTIONS

=cut

###############################################################
# General Options
###############################################################
=pod

=head2 General Options

=over 4

=item -help

Display a brief help message and exit.

=item -version

Display version information and exit.

=item -verbose LEVEL

Set verbosity level to LEVEL.  Default=1.

=back

=cut


###############################################################
# Other Options
###############################################################
=pod

=head2 Other Options

=over 4

=item -someoptions ARG

Example option.

=back

=cut


###############################################################
# Bugs and Limitations
###############################################################
=pod

=head1 BUGS AND LIMITATIONS

Probably many.

=cut


###############################################################
# Footer
###############################################################
=pod

=head1 ACKNOWLEDGEMENTS

Perl by Larry Wall.

=head1 AUTHOR

Bryan Jurish E<lt>moocow@ling.uni-potsdam.deE<gt>

=head1 SEE ALSO

perl(1).

=cut
