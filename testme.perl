#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;

##----------------------------------------------------------------------
sub test_token {
  my $s  = "foo\tbar\tbaz\t\tbonk";
  my $t  = Lingua::TT::Token->newFromString($s);
  my $t2 = $t->new->fromString($s."\n\n");
  print STDERR "$0: test_token() done: what now?\n";
}
#test_token();

##----------------------------------------------------------------------
sub test_sent {
  my $str  = join("\n", "foo\tFOO", "bar\tBAR", "baz\tBAZ")."\n\n";
  my $sent = Lingua::TT::Sentence->newFromString($str);

  my $str2 = join("\n", "foo\n\tFOO", "bar\n\tBAR", "baz\n\tBAZ")."\n\n";
  my $sent2 = Lingua::TT::Sentence->newFromString($str2);
  print STDERR "$0: test_sent() done: what now?\n";
}
#test_sent();

##----------------------------------------------------------------------
sub test_doc {
  my $str1 = join("\n", "foo\tFOO", "bar\tBAR", "baz\tBAZ")."\n\n";
  my $str2 = join("\n", "blink", "blap", "blop")."\n\n";
  my $doc  = Lingua::TT::Document->newFromString($str1.$str2);
  print STDERR "$0: test_doc() done: what now?\n";
}
#test_doc();

##----------------------------------------------------------------------
sub test_io {
  my $ifile = 'test1.t';
  my $ofile = '-';
  my $tti   = Lingua::TT::IO->fromFile($ifile);
  my $tto   = Lingua::TT::IO->toFile($ofile);
  my $doc   = $tti->getDocument;
  $tto->putDocument($doc);
  print STDERR "$0: test_io() done: what now?\n";
}
test_io();


##======================================================================
## MAIN (dummy)
foreach $i (1..3) {
  print STDERR "$0: dummy[$i]\n";
}
