## -*- Mode: CPerl -*-
## File: Lingua::TT::Document.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: TT I/O: Documents


package Lingua::TT::Document;
use Lingua::TT::Token;
use Lingua::TT::Sentence;
use strict;

##==============================================================================
## Globals & Constants

##==============================================================================
## Constructors etc.

## $doc = CLASS_OR_OBJECT->new(@sents)
## + $doc: ARRAY-ref
##     [$sent1, $sent2, ..., $sentN]
sub new {
  my $that = shift;
  return bless([@_], ref($that)||$that);
}

## $doc = CLASS_OR_OBJECT->newFromString($str)
##  + should be equivalent to CLASS_OR_OBJECT->new()->fromString($str)
sub newFromString {
  return $_[0]->new()->fromString($_[1]);
}

##==============================================================================
## Methods: Access

## $bool = $doc->isEmpty()
##  + true iff $sent has no non-empty sentences
sub isEmpty {
  return !grep {!$_->isEmpty} @{$_[0]};
}

## $doc = $doc->rmEmptySentences()
##  + removes empty & undefined sentences from @$doc
sub rmEmptyTokens {
  @{$_[0]} = grep {defined($_) && !$_->isEmpty} @{$_[0]};
  return $_[0];
}

## $nSents = $doc->nSentences()
sub nSentences {
  return scalar(@{$_[0]});
}

## $nToks = $doc->nTokens()
sub nTokens {
  my $n = 0;
  $n += scalar(@$_) foreach (@{$_[0]});
  return $n;
}

##==============================================================================
## Methods: I/O

## $str = $doc->toString()
##  + returns string representing $doc
sub toString {
  return join("\n", map {$_->toString} @{$_[0]})."\n";
}

## $doc = $doc->fromString($str)
##  + parses $doc from string $str
sub fromString {
  #my ($sent,$str) = @_;
  @{$_[0]} = map {Lingua::TT::Sentence->newFromString($_)} split(/(?:\r?\n){2}/,$_[1]);
  return $_[0];
}

##==============================================================================
## Methods: Shuffle & Split

## $doc = $doc->shuffle()
##  + randomly re-orders sentences in @$doc
##  + sensitive to current random seed (set with srand($seed))
sub shuffle {
  my $doc  = shift;
  my @keys = map {rand} @$doc;
  @$doc = @$doc[sort {$keys[$a]<=>$keys[$b]} (0..$#$doc)];
  return $doc;
}

##  @docs = $doc->splitN($n)  ##-- array context
## \@docs = $doc->splitN($n)  ##-- scalar context
##  + splits $doc into $n roughly equally-sized @docs
##  + sentence data is shared (refs) between $doc and @docs
sub splitN {
  my ($doc,$n) = @_;
  my @odocs  = map {$doc->new} (1..$n);
  my @osizes = map {0} @odocs;
  my ($sent,$oi,$oi_min);
  foreach $sent (@$doc) {
    ##-- find smallest @odoc
    $oi_min = 0;
    foreach $oi (1..$#odocs) {
      $oi_min = $oi if ($osizes[$oi] < $osizes[$oi_min]);
    }
    push(@{$odocs[$oi_min]}, $sent);
    $osizes[$oi_min] += scalar(@$sent);
  }
  return wantarray ? @odocs : \@odocs;
}

##==============================================================================
## Footer
1;

__END__
