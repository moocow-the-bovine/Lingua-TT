## -*- Mode: CPerl -*-
## File: Lingua::TT::Diff.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: TT I/O: Document diffs


package Lingua::TT::Diff;
use Lingua::TT::Document;

use Algorithm::Diff;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals & Constants

##==============================================================================
## Constructors etc.

## $diff = CLASS_OR_OBJECT->new(%opts)
## + %$diff, %opts
##   ##-- objects to compare
##   doc1 => $doc1,    ##-- Lingua:TT::Document object (e.g. training)
##   doc2 => $doc2,    ##-- Lingua:TT::Document object (e.g. tokenizer output)
##   ##
##   ##-- comparison options
##   cmpEOS => $bool,        ##-- if true, sentence boundaries will be compared (default=true)
##   cmpComments => $bool,   ##-- if true, non-vanilla tokens will be compared  (default=false)
##   cmpEmpty => $bool,      ##-- if true, empty tokens will be compared        (default=false)
##   ##
##   ##-- cache data
##   seq1 => \@seq1,   ##-- raw strings to compare
##   seq2 => \@seq2,   ##-- raw strings to compare
##   ss1  => \@ss1,    ##-- $doc1 sentence indices: [$seq1i]=>$doc1_sent_i
##   ss2  => \@ss2,    ##-- $doc2 sentence indices: [$seq2i]=>$doc2_sent_i
##   sw1  => \@sw1,    ##-- $doc1 token indices:    [$seq1i]=>$doc1_tok_i  : $w1 = $doc1[$ss1[$seq1i]][$sw1[$seq1i]]
##   sw2  => \@sw2,    ##-- $doc2 token indices:    [$seq2i]=>$doc2_tok_i  : $w2 = $doc2[$ss2[$seq2i]][$sw2[$seq2i]]
##   ##
##   ##-- diff data
##   hunks => \@hunks, ##-- difference hunks: [$hunk1,$hunk2,...]
##                     ## + each $hunk is: [$bitMask, $min1seqi,$max1seqi, $min2seqi,$max2seqi]
sub new {
  my $that = shift;
  my $diff = bless({
		    ##-- docs to compare
		    doc1=>undef,
		    doc2=>undef,

		    ##-- options
		    cmpEOS => 1,
		    cmpEmpty => 0,
		    cmpComments => 0,

		    ##-- cache data
		    seq1=>undef,
		    seq2=>undef,
		    ss1=>undef,
		    ss2=>undef,
		    sw1=>undef,
		    sw2=>undef,

		    ##-- diff data
		    hunks=>undef,

		    ##-- user args
		    @_,
		   }, ref($that)||$that);

  $diff->indexDocument($diff->{doc1}) if (defined($diff->{doc1}));
  $diff->indexDocument($diff->{doc2}) if (defined($diff->{doc2}));
  $diff->compare() if ($diff->{doc1} && $diff->{doc2});
  return $diff;
}

## $diff = $diff->reset()
##  + clears cache and diff data
sub reset {
  my $diff = shift;
  $diff->clearCache;
  delete(@$diff{qw(doc1 doc2 hunks)});
  return $diff;
}

## $diff = $diff->clearCache()
##  + clears cached indices & flat sequences, etc.
sub clearCache {
  my $diff = shift;
  delete(@$diff{qw(seq1 seq2 ss1 ss2 sw1 sw2)});
  return $diff;
}

##==============================================================================
## Methods: Low-Level

## $seq = $diff->indexDocument($doc,$which)
##  + creates @$diff{"ss$i","idx$i"} from $obj
sub indexDocument {
  my ($diff,$doc,$which) = @_;
  $which = 1 if (!defined($which));

  $diff->{"doc${which}"} = $doc;
  my $seq = $diff->{"seq${which}"} = [];
  my $ss  = $diff->{"ss${which}"}  = [];
  my $sw  = $diff->{"sw${which}"}  = [];

  my ($si,$wi, $s,$w);
  foreach $si (0..$#$doc) {
    $s = $doc->[$si];
    foreach $wi (0..$#$s) {
      $w = $s->[$wi];
      next if (!$diff->{cmpComments} && $w->isComment);
      next if (!$diff->{cmpEmpty}    && $w->isEmpty);
      push(@$seq, defined($w->[0]) ? $w->[0] : '');
      push(@$ss,  $si);
      push(@$sw,  $wi);
    }
    if ($diff->{cmpEOS}) {
      push(@$seq, '');
      push(@$ss,  $si);
      push(@$sw,  $#$s+1);
    }
  }

  ##-- add final pseudo-elements to sequence backtranslation indices
  push(@$ss, $#$doc+1);
  push(@$sw, $#$s+1);

  return $diff;
}

##==============================================================================
## Methods: Document selection

## $diff = $diff->doc1($doc1)
##  + set 1st document to compare
sub doc1 {
  $_[0]->indexDocument($_[1],1);
}

## $diff = $diff->doc2($doc2)
##  + set 2nd document to compare
sub doc2 {
  $_[0]->indexDocument($_[1],2);
}

##==============================================================================
## Methods: Comparison

## $diff = $diff->compare()
## $diff = $diff->compare($doc2)
## $diff = $diff->compare($doc1,$doc2)
##  + compare documents, wrapping doc1(), doc2() calls if enough arguments are supplied
sub compare {
  my $diff = shift;

  ##-- args: docs
  $diff->doc1(shift) if (@_ >= 2);
  $diff->doc2(shift) if (@_);

  ##-- sanity check(s)
  confess(ref($diff)."::compare(): {doc1} undefined!") if (!$diff->{doc1});
  confess(ref($diff)."::compare(): {doc2} undefined!") if (!$diff->{doc2});

  ##-- index vars
  my ($ss1,$sw1, $ss2,$sw2) = @$diff{qw(ss1 sw1 ss2 sw2)};

  ##-- compute the diff
  my $adiff = Algorithm::Diff->new(@$diff{qw(seq1 seq2)});
  my $hunks = $diff->{hunks} = [];
  my ($bits, $min1,$max1,$min2,$max2);
  while ($adiff->Next) {
    $bits = $adiff->Diff;
    next if (!$bits);            ##-- don't store identity hunkgs
    ($min1,$max1,$min2,$max2) = $adiff->Get(qw(Min1 Max1 Min2 Max2));
    push(@$hunks, [$bits,
		   #$ss1->[$min1], $sw1->[$min1],   $ss1->[$max1], $sw1->[$max1],
		   #$ss2->[$min2], $sw2->[$min2],   $ss2->[$max2], $sw2->[$max2],
		   ##--
		   $min1,$max1, $min2,$max2,
		  ]);
  }
  return $diff;
}

##==============================================================================
## Methods: I/O

## $diff = $diff->dump($outfile_or_fh,%opts)
##  + %opts:
##     label1  => $label1,  ##-- default: 'doc1'
##     label2  => $label2,  ##-- default: 'doc2'
##     context => $nlines,  ##-- default=4
##     verbose => $bool,    ##-- produce verbose diff or "real" diff (default=false: "real" diff)
sub dump {
  my ($diff,$file,%opts) = @_;
  %opts = (context=>4,
	   label1=>'doc1',
	   label2=>'doc2',
	   verbose=>0,
	   %opts);
  $opts{context} = 4 if (!defined($opts{context}));

  my $fh = ref($file) ? $file : IO::File->new(">$file");
  confess(ref($diff)."::dump(): open failed for '$file': $!") if (!defined($fh));

  $fh->print("*** $opts{label1}\n",
	     "--- $opts{label2}\n");
  my ($seq1,$seq2, $ss1,$sw1, $ss2,$sw2) = @$diff{qw(seq1 seq2 ss1 sw1 ss2 sw2)};
  my ($hunk, $bits,$min1,$max1,$min2,$max2,$i);
  my ($min1c,$max1c,$min2c,$max2c);
  my ($hunkid1,$hunkid2, $code1,$code2);
  foreach $hunk (@{$diff->{hunks}}) {
    ($bits,$min1,$max1,$min2,$max2) = @$hunk;
    next if (!$bits);

    ##-- add context
    ($min1c,$min2c) = map {$_<0 ? 0 : $_} map {$_-$opts{context}} ($min1,$min2);
    ($max1c,$max2c) = map {$_+$opts{context}} ($max1,$max2);
    ($min1c,$max1c) = map {$_ > $#$seq1 ? $#$seq1 : $_} ($min1c,$max1c);
    ($min2c,$max2c) = map {$_ > $#$seq2 ? $#$seq2 : $_} ($min2c,$max2c);

    ##-- hunk ids
    $hunkid1 = ("*** ".($min1c+1).','.($max1c+1)." ***"
		.($opts{verbose} ? " ($min1:$ss1->[$min1].$sw1->[$min1] , $max1:$ss1->[$max1].$sw1->[$max1])" : ''));
    $hunkid2 = ("--- ".($min2c+1).','.($max2c+1)." ---"
		.($opts{verbose} ? " ($min2:$ss2->[$min2].$sw2->[$min2] , $max2:$ss2->[$max2].$sw2->[$max2])" : ''));

    if    ($bits==3) {
      ##-- changed items in $seq1 and $seq2
      $code1=$code2='! ';
    }
    elsif ($bits==2) {
      $code1='? '; ##-- should never be needed!
      $code2='+ ';
    }
    elsif ($bits==1) {
      $code1='- ';
      $code2='? '; ##-- should never be needed!
    }

    ##-- dump this hunk
    $fh->print(
	       ("*" x 15), "\n", ##-- header
	       $hunkid1, "\n",
	       (($bits&1)
		? (
		   (map {('  ',   $seq1->[$_], "\n")}  ($min1c..($min1-1))), ##-- context.BEFORE
		   (map {($code1, $seq1->[$_], "\n")}  ($min1..$max1)),      ##-- hunk.1
		   (map {('  ',   $seq1->[$_], "\n")}  (($max1+1)..$max1c)), ##-- context.AFTER
		  )
		: qw()),
	       ##
	       $hunkid2, "\n",
	       (($bits&2)
		? (
		   (map {('  ',   $seq2->[$_], "\n")}  ($min2c..($min2-1))), ##-- context.BEFORE
		   (map {($code2, $seq2->[$_], "\n")}  ($min2..$max2)),      ##-- hunk.2
		   (map {('  ',   $seq2->[$_], "\n")}  (($max2+1)..$max2c)), ##-- context.AFTER
		  )
		: qw()),
	      );
  }

  ##-- print final newline
  $fh->print("\n");

  return $diff;
}


##==============================================================================
## Footer
1;

__END__
