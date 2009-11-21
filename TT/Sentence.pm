## -*- Mode: CPerl -*-
## File: Lingua::TT::Sentence.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: TT I/O: sentences


package Lingua::TT::Sentence;
use Lingua::TT::Token;
use strict;

##==============================================================================
## Globals & Constants

##==============================================================================
## Constructors etc.

## $sent = CLASS_OR_OBJECT->new(@tokens)
## + $sent: ARRAY-ref
##   [$tok1, $tok2, ..., $tokN]
sub new {
  my $that = shift;
  return bless([@_], ref($that)||$that);
}

## $sent = CLASS_OR_OBJECT->newFromString($str)
sub newFromString {
  return $_[0]->new()->fromString($_[1]);
}

## $sent2 = $sent->copy($depth)
##  + creates a copy of $sent
##  + if $deep is 0, only a shallow copy is created (tokens are shared)
##  + if $deep is >=1 (or <0), sentences are copied as well (tokens are copied)
sub copy {
  my ($sent,$deep) = @_;
  my $sent2 = bless([],ref($sent));
  @$sent2 = $deep ? (map {bless([@$_],ref($_))} @$sent) : @$sent;
  return $sent2;
}

##==============================================================================
## Methods: Access

## $bool = $sent->isEmpty()
##  + true iff $sent has no non-empty tokens
sub isEmpty {
  return !grep {!$_->isEmpty} @{$_[0]};
}

## $sent = $sent->rmEmptyTokens()
##  + removes empty & undefined tokens from @$sent
sub rmEmptyTokens {
  @{$_[0]} = grep {defined($_) && !$_->isEmpty} @{$_[0]};
  return $_[0];
}

## $sent = $sent->rmComments()
##  + removes comment pseudo-tokens from @$sent
sub rmComments {
  @{$_[0]} = grep {!defined($_) || !$_->isComment} @{$_[0]};
  return $_[0];
}

## $sent = $sent->rmNonVanilla()
##  + removes non-vanilla tokens from @$sent
sub rmNonVanilla {
  @{$_[0]} = grep {defined($_) && $_->isVanilla} @{$_[0]};
  return $_[0];
}


##==============================================================================
## Methods: I/O

## $str = $sent->toString()
##  + returns string representing $sent, but without terminating newline
sub toString {
  return join("\n", map {$_->toString} @{$_[0]})."\n";
}

## $sent = $sent->fromString($str)
##  + parses $sent from string $str
sub fromString {
  #my ($sent,$str) = @_;
  @{$_[0]} = map {Lingua::TT::Token->newFromString($_)} split(/[\r\n]+/,$_[1]);
  return $_[0];
}

##==============================================================================
## Methods: Raw Text (heuristic)

## $str = $sent->rawString()
sub rawString {
  my $sent = shift;  ##-- ( \@tok1, \@tok2, ..., \@tokN )
  my @spaces = qw(); ##-- ( $space_before_tok1, ..., $space_before_tokN )

  ##-- insert boundary space
  @spaces = map {''} @$sent;
  my ($i,$t1,$t2);
  foreach $i (1..$#$sent) {
    ($t1,$t2) = @$sent[($i-1),$i];
    next if ($t2->[0] =~ /^(?:[\]\)\%\.\,\:\;\!\?])|\'\'$/); ##-- no token-boundary space BEFORE these text types
    next if ($t1->[0] =~ /^(?:[\[\(])|\`\`$/);               ##-- no token-boundary space AFTER  these text types
    $spaces[$i] = ' ';                                       ##-- default: add token-boundary space
  }

  ##-- dump raw text
  return join('', map {($spaces[$_],$sent->[$_][0])} (0..$#$sent));
}

##==============================================================================
## Footer
1;

__END__
