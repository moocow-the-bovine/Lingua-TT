## -*- Mode: CPerl -*-
## File: Lingua::TT::Diff.pm
## Author: Bryan Jurish <moocow@ling.uni-potsdam.de>
## Descript: TT I/O: Document diffs


package Lingua::TT::Diff;
use Lingua::TT::Document;

use File::Temp;
use IO::File;
use Carp;
use strict;

##==============================================================================
## Globals & Constants

our $DIFF = 'diff'; ##-- search in path

##==============================================================================
## Constructors etc.

## $diff = CLASS_OR_OBJECT->new(%opts)
## + %$diff, %opts
##   ##-- objects to compare
##   doc1 => $doc1,    ##-- Lingua:TT::Document object (e.g. training)
##   doc2 => $doc2,    ##-- Lingua:TT::Document object (e.g. tokenizer output)
##   file1 => $file1,  ##-- sequence dump file for $doc1 (default=temp)
##   file2 => $file2,  ##-- sequence dump file for $doc2 (default=temp)
##   ##
##   ##-- comparison options
##   cmpEOS => $bool,        ##-- if true, sentence boundaries will be compared (default=true)
##   cmpComments => $bool,   ##-- if true, non-vanilla tokens will be compared  (default=false)
##   cmpEmpty => $bool,      ##-- if true, empty tokens will be compared        (default=false)
##   ##
##   ##-- cache data
##   tmp1 => $bool,    ##-- true iff $file1 is a temp
##   tmp2 => $bool,    ##-- true iff $file2 is a temp
##   seq1 => \@seq1,   ##-- raw (text) strings to compare
##   seq2 => \@seq2,   ##-- raw (text) strings to compare
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
		    #file1=>undef,
		    #file2=>undef,

		    ##-- options
		    cmpEOS => 1,
		    cmpEmpty => 0,
		    cmpComments => 0,

		    ##-- cache data
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
  delete(@$diff{qw(doc1 doc2 file1 file2 tmp1 tmp2 hunks)});
  return $diff;
}

## $diff = $diff->clearCache()
##  + clears cached indices & flat sequences, etc.
sub clearCache {
  my $diff = shift;
  delete(@$diff{qw(seq1 seq2 ss1 ss2 sw1 sw2)});
  delete($diff->{file1}) if ($diff->{tmp1});
  delete($diff->{file2}) if ($diff->{tmp2});
  delete(@$diff{qw(tmp1 tmp2)});
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

## $seqfile = $diff->seqFile($which)
##  + creates temporary file for $diff->{"seq${which}"}
sub seqFile {
  my ($diff,$which) = @_;
  $which = 1 if (!$which);

  ##-- sanity check(s)
  confess(ref($diff)."::seqFile($which): sequence '$which' is not defined!") if (!$diff->{"seq${which}"});

  ##-- get tempfile
  my ($fh,$filename);
  if (defined($filename=$diff->{"file${which}"})) {
    $fh = IO::File->new(">$filename");
    $diff->{"tmp${which}"} = 0;
  } else {
    ($fh,$filename) = File::Temp::tempfile("ttdiff_XXXX", SUFFIX=>'.t0');
    $diff->{"file${which}"} = $filename;
    $diff->{"tmp${which}"} = 1;
  }
  confess(ref($diff)."::seqFile($which): open failed for '$filename': $!") if (!defined($fh));

  ##-- dump
  $fh->print(map {$_."\n"} @{$diff->{"seq${which}"}});
  $fh->close();

  return $filename;
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

  ##-- create temp files
  my $file1 = $diff->seqFile(1);
  my $file2 = $diff->seqFile(2);

  ##-- compute & parse the diff (external call)
  my $fh = IO::File->new("$DIFF $file1 $file2|")
    or die(ref($diff)."::compare(): could not open pipe from system diff '$DIFF': $!");
  my ($min1,$min2,$max1,$max2) = (0,0,0,0);
  my $bits  = 0;
  my $hunks = $diff->{hunks} = [];
  my %op2bits = (a=>2,c=>3,d=>1);
  my ($line);
  while (defined($line=<$fh>)) {
    if    ($line =~ /^(\d+)(?:\,(\d+))?([acd])(\d+)(?:\,(\d+))?$/) {
      $bits = $op2bits{$3};
      ($min1,$max1,$min2,$max2) = ($1,$2,$4,$5);
    }
    else {
      next; ##-- ignore
    }
    $max1 = $min1 if (!defined($max1));
    $max2 = $min2 if (!defined($max2));
    push(@$hunks, [$bits, map {$_-1} $min1,$max1,$min2,$max2]);
  }
  $fh->close;

  ##-- unlink temp files
  unlink($file1) if ($diff->{tmp1});
  unlink($file2) if ($diff->{tmp2});
  delete(@$diff{qw(tmp1 tmp2)});

  return $diff;
}

##==============================================================================
## Methods: I/O

##----------------------------------------------------------------------
## Methods: I/O: Dump

## $diff = $diff->dumpContextDiff($outfile_or_fh,%opts)
##  + %opts:
##     label1  => $label1,  ##-- default: $diff->{file1} || 'doc1'
##     label2  => $label2,  ##-- default: $diff->{file2} || 'doc2'
##     context => $nlines,  ##-- default=4
##     verbose => $bool,    ##-- produce verbose diff or "real" diff (default=false: "real" diff)
sub dumpContextDiff {
  my ($diff,$file,%opts) = @_;
  %opts = (context=>4,
	   label1=>($diff->{file1} || 'doc1'),
	   label2=>($diff->{file2} || 'doc2'),
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

##----------------------------------------------------------------------
## Methods: I/O: Text

## $diff = $diff->saveTextFile($filename_or_fh,%opts)
##  + stores text representation of $diff to $filename_or_fh
##  + %opts:
##     header => $bool, ##-- store header? (default=1)
sub saveTextFile {
  my ($diff,$file,%opts) = @_;
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  confess(ref($diff)."::saveTextFile(): open failed for '$file': $!") if (!defined($fh));

  ##-- dump: header
  $opts{header} = 1 if (!defined($opts{header}));
  $fh->print("=== file1: $diff->{file1}\n",
	     "=== file2: $diff->{file2}\n",
	     (map {"=== $_: ".($diff->{$_} ? 1 : 0)."\n"} qw(cmpEOS cmpComments cmpEmpty)),
	     "=== ss1: ", join(' ', @{$diff->{ss1}}), "\n",
	     "=== ss2: ", join(' ', @{$diff->{ss2}}), "\n",
	     "=== sw1: ", join(' ', @{$diff->{sw1}}), "\n",
	     "=== sw2: ", join(' ', @{$diff->{sw2}}), "\n",
	    ) if ($opts{header});

  ##-- dump: hunks (traditional diff format)
  $fh->print("--- HUNKS (".scalar(@{$diff->{hunks}}).")\n");
  my ($seq1,$seq2,$doc1,$doc2,$ss1,$ss2,$sw1,$sw2) = @$diff{qw(seq1 seq2 doc1 doc2 ss1 ss2 sw1 sw2)};
  my ($hunk, $bits,$min1,$max1,$min2,$max2, $addr,$sep);
  foreach $hunk (@{$diff->{hunks}}) {
    ($bits,$min1,$max1,$min2,$max2) = @$hunk;
    next if (!$bits);
    if    ($bits == 1) { $addr = "${min1},${max1}d${min2}"; $sep=''; }
    elsif ($bits == 2) { $addr = "${min1}a,${min2},${max2}"; $sep=''; }
    else               { $addr = "${min1},${max1}c${min2},${max2}"; $sep="---\n"; }
    $fh->print($addr, "\n",
	       #(map {"< $_\n"} @$seq1[$min1..$max1]),
	       #$sep,
	       #(map {"> $_\n"} @$seq2[$min2..$max2]),
	       ##--
	       (map {"< ".$doc1->[$ss1->[$_]][$sw1->[$_]]->toString."\n"} ($min1..$max1)),
	       $sep,
	       (map {"> ".$doc2->[$ss2->[$_]][$sw2->[$_]]->toString."\n"} ($min2..$max2)),
	      );
  }
  $fh->close() if (!ref($file));
  return $diff;
}

## $diff = $CLASS_OR_OBJ->loadTextFile($filename_or_fh,%opts)
##  + %opts: (none)
sub loadTextFile {
  my ($diff,$file,%opts) = @_;
  $diff = $diff->new if (!ref($diff));
  my $fh = ref($file) ? $file : IO::File->new("<$file");
  confess(ref($diff)."::loadTextFile(): open failed for '$file': $!") if (!defined($fh));

  ##-- load
  my %op2bits = (a=>2,c=>3,d=>1);
  my $hunks = $diff->{hunks} = [];
  my ($line, $bits,$min1,$max1,$min2,$max2);
  while (defined($line=<$fh>)) {
    #chomp($line);
    if      ($line =~ /^\=\=\= (s[sw][12]): (.*)$/) {
      $diff->{$1} = [split(/\s+/,$2)];
    }
    elsif ($line =~ /^\=\=\= (\w+): (.*)$/) {
      $diff->{$1} = $2;
    }
    elsif ($line =~ /^(\d+)(?:\,(\d+))?([acd])(\d+)(?:\,(\d+))?$/) {
      $bits = $op2bits{$3};
      ($min1,$max1,$min2,$max2) = ($1,$2,$4,$5);
      $max1 = $min1 if (!defined($max1));
      $max2 = $min2 if (!defined($max2));
      push(@$hunks, [$bits, $min1,$max1,$min2,$max2]);
    }
    ##-- ignore others
  }
  $fh->close() if (!ref($file));

  return $diff;
}

##----------------------------------------------------------------------
## Methods: I/O: Binary

## $diff = $diff->saveBinFile($filename_or_fh)
sub saveBinFile {
  require Storable;
  my ($diff,$file) = @_;
  my ($rc);
  if (ref($file)) {
    $rc = Storable::store_fd($diff,$file);
  } else {
    $rc = Storable::store($diff,$file);
  }
  return $rc ? $diff : undef;
}


## $diff = $CLASS_OR_OBJ->loadBinFile($filename_or_fh)
sub loadBinFile {
  require Storable;
  my ($diff,$file) = @_;
  my ($ref,$rc);
  if (ref($file)) {
    $ref = Storable::retrieve_fd($file);
  } else {
    $ref = Storable::retrieve($file);
  }
  if (ref($diff)) {
    %$diff = %$ref;
    return $diff;
  }
  return $ref;
}


##==============================================================================
## Footer
1;

__END__
