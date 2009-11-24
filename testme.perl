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
  my $raw1 = $sent->rawString();

  my $str2 = join("\n", "foo\n\tFOO", "bar\n\tBAR", "baz\n\tBAZ")."\n\n";
  my $sent2 = Lingua::TT::Sentence->newFromString($str2);
  my $raw2 = $sent2->rawString();

  my $sent3 = Lingua::TT::Sentence->new(map {Lingua::TT::Token->new($_)} qw(`` foo),',',qw('' said he ; bar .));
  my $raw3  = $sent3->rawString;
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
#test_io();

##----------------------------------------------------------------------
use Algorithm::Diff;
sub test_diff_1 {
  my $doc1 = Lingua::TT::Document->fromFile('test1.t');
  my $doc2 = Lingua::TT::Document->fromFile('test2.t');

  my $s1 = $doc1->copy(-1)->canonicalize->flat;
  my $s2 = $doc2->copy(-1)->canonicalize->flat;
  my $keysub = sub {return $_[0][0]};

  my $diff0 = Algorithm::Diff::diff($s1,$s2, $keysub);
  my $sdiff = Algorithm::Diff::sdiff($s1,$s2, $keysub);
  my $cdiff = Algorithm::Diff::compact_diff($s1,$s2, $keysub);

  my $diff = Algorithm::Diff->new($s1,$s2, {keyGen=>$keysub});
  while ($diff->Next) {
    my ($min1,$max1,$min2,$max2) = $diff->Get(qw(Min1 Max1 Min2 Max2));
    my $bits = $diff->Diff();
    my $hunkid = "(bits=$bits) ${min1}:${max1},${min2}:${max2}";
    print
      ("[BEGIN HUNK $hunkid]\n",
       ((!$bits)  ? (map {"=1 ".$_->toString."\n"} @$s1[$min1..$max1]) : qw()), ##-- equal subsequences (#1)
       ((!$bits)  ? (map {"=2 ".$_->toString."\n"} @$s2[$min2..$max2]) : qw()), ##-- equal subsequences (#2)
       (($bits&1) ? (map {"-1 ".$_->toString."\n"} @$s1[$min1..$max1]) : qw()), ##-- delete items from $seq1
       (($bits&2) ? (map {"+2 ".$_->toString."\n"} @$s2[$min2..$max2]) : qw()), ##-- insert items from $seq2
       "[END HUNK $hunkid]\n",
      );
  }

  print STDERR "$0: test_diff_1() done: what now?\n";
}
#test_diff_1();

##----------------------------------------------------------------------
use Lingua::TT::Diff;
sub test_tt_diff {
  my ($file1,$file2) = @_;
  ##--
  #$file1 = "tiger.utf8.orig.32.tt" if (!$file1);
  #$file2 = "tiger.utf8.tok.32.tt"  if (!$file2);
  ##--
  $file1 = "tiger.utf8.orig.1k.tt" if (!$file1);
  $file2 = "tiger.utf8.tok.1k.tt"  if (!$file2);
  ##--
  #$file1 = "tiger.utf8.orig.tt" if (!$file1);
  #$file2 = "tiger.utf8.tok.tt"  if (!$file2);
  ##
  #my $seq1 = Lingua::TT::IO->fromFile($file1)->getLines;
  #my $seq2 = Lingua::TT::IO->fromFile($file2)->getLines;
  #my $diff = Lingua::TT::Diff->new();
  #$diff->compare($seq1,$seq2);

  my $diff = Lingua::TT::Diff->new();
  $diff->compare($file1,$file2, encoding=>'UTF-8');

  ##--
  #$diff->dumpContextDiff('-', verbose=>1);

  ##--
  if (@ARGV) {
    $diff->saveTextFile('-');
    exit(0);
  }
  $diff->saveTextFile('tmp1.ttd');
  my $diff2 = ref($diff)->loadTextFile('tmp1.ttd');
  #$diff2->saveTextFile('-');
  $diff2->saveTextFile('tmp2.ttd');

  print STDERR "$0: test_tt_diff() done: what now?\n";
}
test_tt_diff(@ARGV);

##======================================================================
## MAIN (dummy)
foreach $i (1..3) {
  print STDERR "$0: dummy[$i]\n";
}