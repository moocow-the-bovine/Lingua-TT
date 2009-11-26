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
push(@ARGV,'-') if (!@ARGV);

our $diff = Lingua::TT::Diff->new(%diffargs);
our $dfile = shift(@ARGV);
$diff->loadTextFile($dfile)
  or die("$0: load failed from '$dfile': $!");

##--------------------------------------------------------------
## MAIN: Heuristics: Simple
my ($seq1,$seq2,$hunks) = @$diff{qw(seq1 seq2 hunks)};
my ($op,$min1,$max1,$min2,$max2,$fix);
my (@items1,@items2);
foreach $hunki (0..$#$hunks) {
  $hunk = $hunks->[$hunki];
  ($op,$min1,$max1,$min2,$max2, $fix) = @$hunk;
  next if (defined($fix)); ##-- already resolved
  @items1 = @$seq1[$min1..$max1];
  @items2 = @$seq2[$min2..$max2];

  ##-- DELETE: $1 ~ cmt|eos|punct -> $1
  if ($op eq 'd' && @items1==grep {/^\%\%/ || /^$/ || /^[[:punct:]]+\t/} @items1)
    {
      $hunk->[5] = 1;
      ##-- check for subsequent related hunk: <'' ~EOS  <CMT >''
      if ($hunki < $#$hunks && $max1 < $#$seq1) {
	$hunk2 = $hunks->[$hunki+1];
	if ($seq1->[$max1+1] =~ /^$/
	    && $hunk2->[0] eq 'c'
	    && $hunk2->[1] == ($max1+2)
	    && ($hunk2->[2]-$hunk2->[1]+1) == 1
	    && ($hunk2->[4]-$hunk2->[3]+1) == 1
	    && $seq1->[$hunk2->[1]] =~ /^\%\%/
	    && $seq2->[$hunk2->[3]] =~ /^[[:punct:]]+\t/)
	  {
	    $hunk2->[5] = 1;
	  }
      }
    }
  ##-- INSERT: $2 ~ cmt|eos -> $1
  elsif ($op eq 'a' && @items2==(grep {/^$/ || /^$/} @items2))
    {
      $hunk->[5] = 1;
    }
  ##-- CHANGE: $1 ~ cmt|eos|punct & $2 ~ punct|eos -> $1
  elsif ($op eq 'c'
	 && @items1==(grep {/^\%\%/ || /^$/ || /^[[:punct:]]+\t/} @items1)
	 && @items2==(grep {/^$/ || /^[[:punct:]](?:\t|$)/} @items2))
    {
      $hunk->[5] = 1;
    }
  ##-- CHANGE: $1 ~ /CARD+/ & $2 ~ /CARD/ -> $2
  elsif ($op eq 'c'
	 && @items1==(grep {/^\d+\tCARD$/} @items1)
	 && @items2==1
	 && $items2[0] =~ /^\d[\d\_]+(?:\t.*)?\tCARD(?:\t|$)/)
    {
      $hunk->[5] = 2;
    }
}


##--------------------------------------------------------------
## MAIN: save
$diff->saveTextFile($outfile)
  or die("$0: save failed to '$outfile': $!");


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
