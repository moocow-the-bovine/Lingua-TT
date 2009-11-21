## -*- Mode: CPerl -*-
## File: Lingua::TT::Diff.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: TT I/O: Document diffs


package Lingua::TT::Diff;
use Lingua::TT::Document;

use Algorithm::Diff;
use strict;

##==============================================================================
## Globals & Constants

##==============================================================================
## Constructors etc.

## $diff = CLASS_OR_OBJECT->new(%opts)
## + %$diff, %opts
##   ##-- objects to compare
##   obj1 => $obj1,    ##-- Lingua:TT::(Document|Sentence|Token) object
##   obj2 => $obj2,    ##-- Lingua:TT::(Document|Sentence|Token) object
##   ##
##   ##-- low-level data
##   key1 => \&cb1,    ##-- key-generation callback for $obj1
##   key2 => \&cb2,    ##-- key-generation callback for $obj2
##   seq1 => \@seq1,   ##-- raw strings to compare
##   seq2 => \@seq2,   ##-- raw strings to compare
##   idx1 => \@idx1,   ##-- index hash for \@seq1: [$i1]=>"$indexString1"
##   idx2 => \@idx2,   ##-- index hash for \@seq2: [$i2]=>"$indexString2"
##   adiff => $adiff,  ##-- underlying Algorithm::Diff object
sub new {
  my $that = shift;
  my $diff = bless({
		    ##-- user data
		    obj1=>undef,
		    obj2=>undef,

		    ##-- low-level data
		    key1=>undef,
		    key2=>undef,
		    seq1=>undef,
		    seq2=>undef,
		    idx1=>undef,
		    idx2=>undef,
		    adiff=>undef,

		    ##-- user args
		    @_,
		   }, ref($that)||$that);
  return $diff;
}

##==============================================================================
## Methods: Low-Level

## $seq = $diff->parseObject($obj,$i)
##  + creates @$diff{"seq$i","idx$i"} from $obj
sub parseObject {
  my ($diff,$obj,$i) = @_;
  
}


##==============================================================================
## Methods: I/O


##==============================================================================
## Footer
1;

__END__
