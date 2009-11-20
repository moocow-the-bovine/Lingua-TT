#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION = "0.01";

##-- program vars
our $progname     = basename($0);

our $frac1        = undef;
our $n1           = undef;
our $outfile1     = '-';
our $outfile2     = '-';
our $srand        = 0;
our $bytoken      = 0;

our $verbose      = 1;

our %ioargs = (encoding=>'UTF-8');

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   'man|m'  => \$man,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- Selection
	   'bytoken|bytok|token|t!' => \$bytoken,
	   'bysentence|bysent|sentence|s!' => sub { $bytoken = !$_[1]; },
	   'frac1|f1|f=f' => \$frac1,
	   'n1|n=i' => \$n1,
	   'srand|r=i' => \$srand,

	   ##-- I/O
	   'output1|o1=s' => \$outfile1,
	   'output2|o2=s' => \$outfile2,
	   'encoding|e=s' => \$ioargs{encoding},
	  );

pod2usage({
	   -msg=>'You must specify either -f or -n!',
	   -exitval=>0,
	   -verbose=>0
	  }) if (!$frac1 && !$n1);
pod2usage({
	   -exitval=>0,
	   -verbose=>0
	  }) if ($help);
pod2usage({
	   -exitval=>0,
	   -verbose=>1
	  }) if ($man);

if ($version || $verbose >= 2) {
  print STDERR "$progname version $VERSION by Bryan Jurish\n";
  exit 0 if ($version);
}

##----------------------------------------------------------------------
## Subs: messages
##----------------------------------------------------------------------

# undef = vmsg($level,@msg)
#  + print @msg to STDERR if $verbose >= $level
sub vmsg {
  my $level = shift;
  print STDERR (@_) if ($verbose >= $level);
}

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
push(@ARGV, '-') if (!@ARGV);

##-- set random seed
srand($srand) if (defined($srand));

##-- read in source file
my ($ttin);
our $doc = Lingua::TT::Document->new();
our $ntoks = 0;
my ($docin);
foreach $infile (@ARGV) {
  $ttin = Lingua::TT::IO->fromFile($infile,%ioargs)
    or die("$0: open failed for file '$infile': $!");
  $docin = $ttin->getDocument;
  push(@$doc,@$docin)
}

##-- stats
$nsents = $doc->nSentences;
$ntoks  = $doc->nTokens;
$nitems = $bytoken ? $ntoks : $nsents;
$n1     = $frac1 * $nitems if (defined($frac1));

##-- report
print STDERR
  ("$progname: got $ntoks tokens in $nsents sentences total\n",
  );

##-- output: file 1
$ntoks1 = $nsents1 = 0;
our $ttout1 = Lingua::TT::IO->toFile($outfile1,%ioargs)
  or die("$0: open failed for '$outfile1': $!");
while (@$doc && $n1 > 0) {
  $si = int(rand(@$doc));
  $s  = splice(@$doc,$si,1);
  $ttout1->putSentence($s);

  ##-- count number of tokens in output files
  $ntoks1 += @$s;
  $nsents1++;

  $n1 -= $bytoken ? scalar(@$s) : 1;
}
$ttout1->close;

##-- print all remaining sentences as-is to $outfile2
$ttout2 = Lingua::TT::IO->toFile($outfile2,%ioargs)
  or die("$0: open failed for '$outfile2': $!");
$ttout2->putDocument($doc);
$ttout2->close();

##-- Summarize
$ntoks2  = $ntoks - $ntoks1;
$nsents2 = $nsents - $nsents1;

$flen = length($outfile1) > length($outfile2) ? length($outfile1) : length($outfile2);
$ilen = length($ntoks);

print STDERR
  (sprintf("\t+ %-${flen}s : %${ilen}d sentences (%6.2f %%)   /   %${ilen}d tokens (%6.2f %%)\n",
	   $outfile1,
	   $nsents1, 100.0*$nsents1/$nsents,
	   $ntoks1, 100.0*$ntoks1/$ntoks),
sprintf("\t+ %-${flen}s : %${ilen}d sentences (%6.2f %%)   /   %${ilen}d tokens (%6.2f %%)\n",
	   $outfile2,
	   $nsents2, 100.0*$nsents2/$nsents,
	   $ntoks2, 100.0*$ntoks2/$ntoks),
  );


__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-split2.perl - split up .t, .tt, and .ttt files into two parts

=head1 SYNOPSIS

 tt-split2.perl OPTIONS [FILE(s)]

 General Options:
   -help
   -version
   -verbose LEVEL

 Selection Options
   -bytoken , -bysentence  ##-- default: -bysentence
   -frac    FLOAT          ##-- fraction of total items for -output1
   -n       NSENTS         ##-- absolute number of total items for -output1
   -srand   SEED           ##-- default: none (perl default)

 I/O Options:
   -output1 OUTFILE1
   -output2 OUTFILE2

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

