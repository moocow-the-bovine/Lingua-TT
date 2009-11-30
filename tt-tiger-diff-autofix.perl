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
## subs

## $max1 = hunk_max1($hunk)
##   + not suitable for range
sub hunk_max1 {
  return $_->[2] > $_->[1] ? $_->[2] : $_->[1];
}

## $max2 = hunk_max2($hunk)
##   + not suitable for range
sub hunk_max2 {
  return $_->[4] > $_->[3] ? $_->[4] : $_->[3];
}

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
push(@ARGV,'-') if (!@ARGV);

our $diff = Lingua::TT::Diff->new(%diffargs);
our $dfile = shift(@ARGV);
$diff->loadTextFile($dfile)
  or die("$0: load failed from '$dfile': $!");

##-- common vars
my ($seq1,$seq2,$hunks) = @$diff{qw(seq1 seq2 hunks)};
my ($op,$min1,$max1,$min2,$max2,$fix);
my (@items1,@items2);
my ($item1,$item2, $i1,$i2);


##--------------------------------------------------------------
## MAIN: heuristics
foreach $hunk (@$hunks) {
  ($op,$min1,$max1,$min2,$max2, $fix) = @$hunk;
  next if ($fix); ##-- already fixed
  @items1 = @$seq1[$min1..$max1];
  @items2 = @$seq2[$min2..$max2];

  ##-- DELETE: $1 ~ cmt|eos -> $1
  if ($op eq 'd' && @items1==(grep {/^(?:\%\%|$)/} @items1))
    {
      $hunk->[5] = 1;
    }
  ##-- INSERT: $2 ~ cmt|eos -> $1
  elsif ($op eq 'a' && @items2==(grep {/^(?:\%\%|$)/} @items2))
    {
      $hunk->[5] = 1;
    }
  ##-- DELETE: $1 ~ "''"@eos -> $1
  elsif ($op eq 'd' && @items1==1 && $items1[0]=~/^\'\'\t/ && ($max1==$#$seq1 || $seq1->[$max1+1]=~/^$/))
    {
      $hunk->[5] = 1;
    }
  ##-- INSERT: $2 ~ "''"@bos -> $1
  elsif ($op eq 'a' && @items2==1 && $items2[0]=~/^\'\'(?:\t|$)/ && ($min2==0 || $seq2->[$min2-1]=~/^$/))
    {
      $hunk->[5] = 1;
    }
  ##-- DELETE: $1 ~ (*) @ eos -> $1 : DANGEROUS
  elsif ($op eq 'd' && @items1==1)
    {
      $hunk->[5] = 1;
    }
  ##-- CHANGE: $1 ~ (%%) & $2 ~ (*) @ bos -> $1  : DANGEROUS
  elsif ($op eq 'c'
	 && @items1==1 && $items1[0] =~ /^\%\%/
	 && @items2==1 && ($min2==0 || $seq2->[$min2-1]=~/^$/))
    {
      $hunk->[5] = 1;
    }
  ##-- CHANGE: $1 ~ (%%) & $2 ~ (''/*) @ bos -> $1 : DANGEROUS (with ellipsis)
  elsif ($op eq 'c'
	 && @items1==(grep {/^\%\%/} @items1)
	 && @items2==1
	 && $items2[0] =~ /^\'\'(?:\t|$)/
	 && ($min2==0 || $seq2->[$min2-1]=~/^$/))
    {
      $hunk->[5] = 1;
    }
  ##-- CHANGE: $1 ~ ([[:punct:]]/*)* & $2 ~ ([:punct:]/*)* --> $1
  elsif ($op eq 'c'
	&& $items1[0]=~/^\.\.\.\t/
	&& @items1==(grep {/^[[:punct:]]+\t/} @items1)
	&& @items2==(grep {/^[[:punct:]]+(?:\t|$)/} @items2))
    {
      $hunk->[5] = 1;
    }
  ##-- CHANGE: Numeric Grouping: $1 ~ ((%%*|CARD)+) & $2 ~ (*/CARD) -> $2
  elsif ($op eq 'c'
      && @items1==(grep {/^\%\%/ || /^\d+\tCARD$/} @items1)
      && @items2==1
      && $items2[0] =~ /^\d[\d\_]+(?:\t.*)?\tCARD(?:\t|$)/)
    {
      $item2 = $items2[0];
      $item2 =~ s/\t.*//;
      $hunk->[5] = [(grep {/^\%\%/} @items1), "$item2\tCARD"];
    }
  ##-- CHANGE: Dates: $1 ~ (... (NN|CARD)) & $2 ~ DATE -> text($2).("=" tag($1)).analyses($2)
  elsif ($op eq 'c'
	 && @items2==1
	 && $items2[0] =~ /\t\$DATE(?:\t|$)/
	 && $items1[$#items1] =~ /\t(?:NN|CARD)$/)
    {
      $tag1 = $items1[$#items1];   $tag1  =~ s/^.*\t//;
      $txt2 = $items2[0];          $txt2  =~ s/\t.*//;
      $anl2 = $items2[0];          $anl2  =~ s/^[^\t]*\t//;
      $hunk->[5] = [$txt2."\t".'='.$tag1."\t".$anl2];
    }
  ##-- CHANGE: Dates: $1 ~ (ADJ*) & $2 ~ DATE -> text($2).("=" tag(last($1))).analyses($2)
  elsif ($op eq 'c'
	 && @items2==1
	 && $items2[0] =~ /\t\$DATE(?:\t|$)/
	 && @items1==(grep {/\tADJ/} @items1))
    {
      $tag1 = $items1[$#items1];   $tag1  =~ s/^.*\t//;
      $txt2 = $items2[0];          $txt2  =~ s/\t.*//;
      $anl2 = $items2[0];          $anl2  =~ s/^[^\t]*\t//;
      $hunk->[5] = [$txt2."\t".'='.$tag1."\t".$anl2];
    }
  ##-- CHANGE: Abbrs: $1 ~ (*/* ./$. (eos|cmt)*) & $2 ~ (*./XY,$ABBREV) -> $1
  elsif ($op eq 'c'
	 && @items1>=2
	 && $items1[1] =~ /^\.\t/
	 && (@items1-2)==(grep {/^(?:\%\%|$)/} @items1[2..$#items1])
	 && @items2==1
	 && $items2[0] =~ /\t\$ABBREV/)
    {
      $hunk->[5] = 1;
    }
  ##-- CHANGE: Numeric breaks: $1 ~ (*[[:digit:]]*/*) & $2 ~ (...) -> $1
  elsif ($op eq 'c'
	 && @items1==1
	 && $items1[0] =~ /^[^\t]*\d/)
    {
      $hunk->[5] = 1;
    }
  ##-- CHANGE: Punctuation breaks: $1 ~ (*[[:punct:]]*/*) & $2 ~ (...) -> $1
  elsif ($op eq 'c'
	 && @items1==1
	 && $items1[0] =~ /^[^\t]*[[:punct:]]/)
    {
      $hunk->[5] = 1;
    }
  ##-- CHANGE: Punctuation non-breaks: $1 ~ (*/* */\'\w+) & $2 ~ (...) --> $1
  elsif ($op eq 'c'
	 && @items1==2
	 && $items1[1] =~ /^\'\w+\t/
	 && @items2==1)
    {
      $hunk->[5] = 1;
    }
  ##-- CHANGE: MWE (NE): $1 ~ (*/NE)+ & $2 ~ (*_*/-) -> text($2) "=NE"
  elsif ($op eq 'c'
	 && @items1==(grep {/\tNE$/} @items1)
	 && @items2==1
	 && $items2[0] =~ /^[[:alpha:]\_]+$/)
    {
      $hunk->[5] = [$items2[0]."\t=NE"];
    }
  ##-- CHANGE: MWE (NN|TRUNC): $1 ~ (*/(NN|TRUNC))+ & $2 ~ (*_*/-) -> text($2) "=NN"
  elsif ($op eq 'c'
	 && @items1==(grep {/\t(?:NN|TRUNC)$/} @items1)
	 && @items2==1
	 && $items2[0] =~ /^[[:alpha:]\_]+$/)
    {
      $hunk->[5] = [$items2[0]."\t=NN"];
    }
  ##-- CHANGE: MWE (FM): $1 ~ (*/FM)+ & $2 ~ (*_*/-) -> text($2) "=FM"
  elsif ($op eq 'c'
	 && @items1==(grep {/\tFM$/} @items1)
	 && @items2==1
	 && $items2[0] =~ /^[[:alpha:]\_]+$/)
    {
      $hunk->[5] = [$items2[0]."\t=FM"];
    }
  ##-- CHANGE: MWE ((ADJ|ART) (NN|NE)+): $1 ~ (*/(ADJ|ART) */(NN|NE))+ & $2 ~ (*_*/-) -> text($2) "=".tag(last($1))
  elsif ($op eq 'c'
	 && @items1>=2
	 && $items1[0] =~ /\t(?:ADJ|ART$)/
	 && (@items1-1)== (grep {/\tN[NE]$/} @items1[1..$#items1])
	 && @items2==1
	 && $items2[0] =~ /^[[:alpha:]\_]+$/)
    {
      $tag1 = $items1[$#items1];
      $tag1 =~ s/^[^\t]*//;
      $hunk->[5] = [$items2[0]."\t=".$tag1];
    }
  ##-- CHANGE: MWE (NN ART NN): $1 ~ (*/NN */ART */NN)+ & $2 ~ (*_*/-) -> text($2) "=NN"
  elsif ($op eq 'c'
	 && @items1==3
	 && $items1[0] =~ /\tNN$/
	 && $items1[1] =~ /\tART$/
	 && $items1[2] =~ /\tNN$/
	 && @items2==1
	 && $items2[0] =~ /^[[:alpha:]\_]+$/)
    {
      $hunk->[5] = [$items2[0]."\t=NN"];
    }
  ##-- CHANGE: MWE (NE NN): $1 ~ (*/NE */NN)+ & $2 ~ (*_*/-) -> text($2) "=NE"
  elsif ($op eq 'c'
	 && @items1==2
	 && $items1[0] =~ /\tNE$/
	 && $items1[1] =~ /\tNN$/
	 && @items2==1
	 && $items2[0] =~ /^[[:alpha:]\_]+$/)
    {
      $hunk->[5] = [$items2[0]."\t=NE"];
    }
  ##-- CHANGE: MWE (NN NE): $1 ~ (*/NN */NE)+ & $2 ~ (*_*/-) -> text($2) "=NE"
  elsif ($op eq 'c'
	 && @items1==2
	 && $items1[0] =~ /\tNN$/
	 && $items1[1] =~ /\tNE$/
	 && @items2==1
	 && $items2[0] =~ /^[[:alpha:]\_]+$/)
    {
      $hunk->[5] = [$items2[0]."\t=NE"];
    }
  ##-- CHANGE: MWE (bad): $1 ~ (... */(APPR*|KON|PIAT) ...) --> $1
  elsif ($op eq 'c'
	 && @items1>1
	 && (grep { /\t(?:APPR|KON|PIAT)/ } @items1)
	 && @items2==1
	 && $items2[0] =~ /^[[:alpha:]\_]+$/)
    {
      $hunk->[5] = 1;
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

tt-tiger-diff-auto.perl - heuristically resolve some conflicts in TIGER - ToMaSoTaTh tt-diffs

=head1 SYNOPSIS

 tt-tiger-diff-auto.perl OPTIONS [TT_DIFF_FILE=-]

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
