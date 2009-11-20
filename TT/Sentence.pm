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
## Footer
1;

__END__
