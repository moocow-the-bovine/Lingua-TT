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
##   ##-- sequences to compare
##   seq1  => \@seq1,     ##-- raw TT line data (default: EMPTY); see $diff->sequenceXYZ() methods
##   seq2  => \@seq2,     ##-- raw TT line data (default: EMPTY); see $diff->sequenceXYZ() methods
##   ##
##   file1 => $file1,     ##-- source name for $seq1 (default: none)
##   file2 => $file2,     ##-- source name for $seq2 (default: none)
##   ##
##   key1  => \&keysub,   ##-- keygen sub for $seq1 (default=\&ksText), called as $key=$keysub->($diff,$line)
##   key2  => \&keysub,   ##-- keygen sub for $seq2 (default=\&ksText), called as $key=$keysub->($diff,$line)
##   ##
##   ##-- misc options
##   keeptmp => $bool,    ##-- if true, temp files will not be unlinked (default=false)
##   ##
##   ##-- cache data
##   tmpfile1 => $tmp1,   ##-- filename: temporary key-file dump for $seq1
##   tmpfile2 => $tmp2,   ##-- filename: temporary key-file dump for $seq2
##   ##
##   ##-- diff data
##   hunks => \@hunks,    ##-- difference hunks: [$hunk1,$hunk2,...]
##                        ## + each $hunk is: [$opCode, $min1,$max1, $min2,$max2, $resolve]
##                        ## + $opCode is as for traditional 'diff':
##                        ##    'a' (add)   : Add     @$seq2[$min2..$max2], align after ($min1==$max1) of $seq1
##                        ##    'd' (delete): Delete  @$seq1[$min1..$max1], align after ($min2==$max2) of $seq2
##                        ##    'c' (change): Replace @$seq1[$min1..$max1] with @$seq2[$min2..$max2]
##                        ## + $resolve is one of:
##                        ##    $which  : int (1 or 2): use corresponding item(s) of "seq${which}"
##                        ##    \@items : ARRAY-ref: resolve conflict with \@items
sub new {
  my $that = shift;
  my $diff = bless({
		    ##-- sequences to compare
		    seq1 => [],
		    seq2 => [],
		    file1=>undef,
		    file2=>undef,
		    key1 => \&ksText,
		    key2 => \&ksText,

		    ##-- cache data
		    tmpfile1 => undef,
		    tmpfile2 => undef,
		    keeptmp  => 0,

		    ##-- diff data
		    hunks => [],

		    ##-- user args
		    @_,
		   }, ref($that)||$that);

  return $diff;
}

## $diff = $diff->reset()
##  + clears cache and diff data
sub reset {
  my $diff = shift;
  $diff->clearCache;
  @{$diff->{seq1}} = qw();
  @{$diff->{seq2}} = qw();
  @{$diff->{hunks}} = qw();
  delete(@$diff{qw(file1 file2)});
  return $diff;
}

## $diff = $diff->clearCache()
##  + clears & unlinks cached temp files
sub clearCache {
  my $diff = shift;
  #@{$diff->{seq1}} = qw();
  #@{$diff->{seq2}} = qw();
  unlink($_) foreach (grep {!$diff->{keeptmp} && defined($_)} @$diff{qw(tmpfile1 tmpfile2)});
  delete(@$diff{qw(tmpfile1 tmpfile2)});
  return $diff;
}

##==============================================================================
## Methods: Key Generation Subs

## $key = $diff->ksText($line)
##  + key-generation sub: 'text' field
sub ksText {
  return ($_[1] =~ /^([^\t\n\r]*)/ ? $1 : '');
}

## $key = $diff->ksTag($line)
##  + key-generation sub: 'tag' field
sub ksTag {
  return ($_[1] =~ /^[^\t]*[\t\n\r][\n\r]*([^\t]*)/ ? $1 : '');
}

## $key = $diff->ksAll($line)
##  + key-generation sub: entire line
sub ksAll {
  return $_[1];
}


##==============================================================================
## Methods: Sequence Selection

##----------------------------------------------------------------------
## Methods: Sequence Selection: High-Level

## $diff = $diff->seq1($src,%opts)
##  + wrapper for $diff->setSequence(1,...)
sub seq1 {
  return $_[0]->setSequence(1,@_[1..$#_]);
}

## $diff = $diff->seq2($src,%opts)
##  + wrapper for $diff->setSequence(2,...)
sub seq2 {
  return $_[0]->setSequence(2,@_[1..$#_]);
}

## $diff = $diff->setSequence($which,$src,%opts)
##   + sets sequence $which (1 or 2) from $src
##   + $src may be one of the following:
##     - a Lingua::TT::Sentence object
##     - a Lingua::TT::Document object
##     - a Lingua::TT::IO object
##     - a flat array-ref of line-strings (without terminating newlines)
##     - a filehandle
##     - a filename
BEGIN { *isa = \&UNIVERSAL::isa; }
sub setSequence {
  my ($diff,$i,$src,%opts) = @_;
  $i = $diff->checkWhich($i);
  if (isa($src,'Lingua::TT::Sentence')) {
    return $diff->sequenceSentence($i,$src,%opts);   ##-- Lingua::TT::Sentence
  }
  elsif (isa($src,'Lingua::TT::Document')) {
    return $diff->sequenceDocument($i,$src,%opts);   ##-- Lingua::TT::Document
  }
  elsif (isa($src,'Lingua::TT::IO')) {
    return $diff->sequenceIO($i,$src,%opts);         ##-- Lingua::TT::IO
  }
  elsif (isa($src,'IO::Handle')) {
    return $diff->sequenceFile($i,$src,%opts);       ##-- IO::Handle
  }
  elsif (isa($src,'ARRAY')) {
    return $diff->sequenceLines($i,$src,%opts);      ##-- array of lines
  }
  elsif (!ref($src)) {
    return $diff->sequenceFile($i,$src,%opts);       ##-- filename
  }
  ##
  return $diff->sequenceFile($i,$src,%opts);         ##-- other ref; maybe a filehandle?
}

##----------------------------------------------------------------------
## Methods: Sequence Selection: Low-Level

## $which = $diff->checkWhich($which)
##  + common sanity check for '$which' values (1 or 2)
sub checkWhich {
  my ($diff,$which) = @_;
  $which = 0 if (!defined($which));
  if ($which != 1 && $which != 2) {
    confess(ref($diff)."::checkWhich(): sequence \$which must be 1 or 2 (got='$which'): assuming '1'");
    return 1;
  }
  return $which;
}

## $diff = $diff->sequenceDocument($which,$doc)
##  + populate sequence $which (1 or 2) from Lingua::TT::Document $doc
##  + calls $diff->sequenceSentence()
sub sequenceDocument {
  my ($diff,$which,$doc) = @_;
  $which = $diff->checkWhich($which);
  $diff->{"file${which}"}   = "$doc";     ##-- ugly but at least non-empty
  @{$diff->{"seq${which}"}} = map {join("\t",@$_)} @{$doc->flat};
  return $diff;
}

## $diff = $diff->sequenceSentence($which,$sent)
##  + populate sequence $which (1 or 2) from Lingua::TT::Sentence $sent
sub sequenceSentence {
  my ($diff,$which,$sent) = @_;
  $which = $diff->checkWhich($which);
  $diff->{"file${which}"}   = "$sent";    ##-- ugly but at least non-empty
  @{$diff->{"seq${which}"}} = map {join("\t",@$_)} @$sent;
  return $diff;
}

## $diff = $diff->sequenceLines($which,\@lines)
##  + populate sequence $which (1 or 2) from \@lines
sub sequenceLines {
  my ($diff,$which,$lines) = @_;
  $which = $diff->checkWhich($which);
  $diff->{"file${which}"}   = "$lines";
  @{$diff->{"seq${which}"}} = @$lines;
  return $diff;
}

## $diff = $diff->sequenceIO($which,$ttio)
##  + populate sequence $which (1 or 2) from Lingua::TT::IO $ttio
sub sequenceIO {
  my ($diff,$which,$ttio) = @_;
  $which = $diff->checkWhich($which);
  $diff->{"file${which}"}   = $ttio->{name};
  @{$diff->{"seq${which}"}} = $ttio->getLines;
  return $diff;
}

## $diff = $diff->sequenceFile($which,$filename_or_fh,%opts)
##   + generate sequence $which (1 or 2) from $filename_or_fh
##   + %opts are passed to Lingua::TT::IO->new()
sub sequenceFile {
  my ($diff,$which,$file,%opts) = @_;
  return $diff->sequenceIO($which,Lingua::TT::IO->fromFile($file,%opts));
}


##==============================================================================
## Methods: Comparison

## $diff = $diff->compare()
## $diff = $diff->compare($src2)
## $diff = $diff->compare($src1,$src2,%opts)
##  + compare currently selected sequences, wrapping setSequence() calls if required
sub compare {
  my ($diff,$src1,$src2,%opts) = @_;

  ##-- args: sequences
  $diff->seq1($src1,%opts) if (defined($src1));
  $diff->seq2($src2,%opts) if (defined($src2));

  ##-- sanity check(s)
  confess(ref($diff)."::compare(): {seq1} undefined!") if (!$diff->{seq1});
  confess(ref($diff)."::compare(): {seq2} undefined!") if (!$diff->{seq2});

  ##-- create temp files
  my $file1 = $diff->seqTempFile(1);
  my $file2 = $diff->seqTempFile(2);

  ##-- compute & parse the diff (external call)
  my $fh = IO::File->new("$DIFF $file1 $file2|")
    or die(ref($diff)."::compare(): could not open pipe from system diff '$DIFF': $!");
  binmode($fh,':utf8');
  my ($op,$min1,$min2,$max1,$max2) = ('',0,0,0,0);
  @{$diff->{hunks}} = qw();
  my $hunks = $diff->{hunks};
  my ($line);
  while (defined($line=<$fh>)) {
    if ($line =~ /^(\d+)(?:\,(\d+))?([acd])(\d+)(?:\,(\d+))?$/) {
      ($min1,$max1, $op, $min2,$max2) = ($1,$2, $3, $4,$5);
    }
    else {
      next; ##-- ignore
    }
    if    ($op eq 'a') { $max1=$min1++; }
    elsif ($op eq 'd') { $max2=$min2++; }
    $max1 = $min1 if (!defined($max1));
    $max2 = $min2 if (!defined($max2));
    push(@$hunks, [$op, map {$_-1} $min1,$max1,$min2,$max2]);
  }
  $fh->close;

  ##-- unlink temp files
  if (!$diff->{keeptmp}) {
    unlink($file1);
    unlink($file2);
    delete(@$diff{qw(tmpfile1 tmpfile2)});
  }

  return $diff;
}

##----------------------------------------------------------------------
## Methods: Comparison: Low-Level

## $tmpfile = $diff->seqTempFile($which)
##  + creates temporary key-dump file $seq->{"tmpfile${which}"} for $diff->{"seq${which}"}
sub seqTempFile {
  my ($diff,$which) = @_;

  ##-- sanity check(s)
  $which = $diff->checkWhich($which);
  confess(ref($diff)."::seqFile($which): sequence '$which' is not defined!")
    if (!$diff->{"seq${which}"});

  ##-- get tempfile
  my ($fh,$filename) = File::Temp::tempfile("ttdiff_XXXX", SUFFIX=>'.t0', UNLINK=>(!$diff->{keeptmp}) );
  confess(ref($diff)."::seqFile($which): open failed for '$filename': $!") if (!defined($fh));
  binmode($fh,':utf8');

  ##-- dump
  my $keysub = $diff->{"key${which}"};
  if (defined($keysub)) {
    $fh->print(map {$keysub->($diff,$_)."\n"} @{$diff->{"seq${which}"}});
  } else {
    $fh->print(@{$diff->{"seq${which}"}});
  }
  $fh->close();

  return $diff->{"tmpfile${which}"} = $filename;
}

##==============================================================================
## Methods: I/O

##----------------------------------------------------------------------
## Methods: I/O: Low-Level

## $mergedStr = $diff->sharedString($tok1str,$tok2str)
sub sharedString {
  my ($diff,$str1,$str2) = @_;
  my @w1 = defined($str1) ? split(/[\t\n\r]/,$str1) : qw();
  my @w2 = defined($str2) ? split(/[\t\n\r]/,$str2) : qw();
  my @w12 = map {
    (defined($w1[$_])
     ? (defined($w2[$_])
	? ($w1[$_] eq $w2[$_]
	   ? "=$w1[$_]"
	   : "<$w1[$_]\t>$w2[$_]")
	: "<$w1[$_]")
     : (defined($w2[$_])
	? ">$w2[$_]"
	: ''))
  } (0..($#w1 > $#w2 ? $#w1 : $#w2));
  return "\t".join("\t", @w12)."\n";
}

##----------------------------------------------------------------------
## Methods: I/O: Text

## $diff = $diff->saveTextFile($filename_or_fh,%opts)
##  + stores text representation of $diff to $filename_or_fh
##  + %opts:
##     header => $bool, ##-- store header? (default=1)
##     files  => $bool, ##-- store filenames (defualt=1)
##     shared => $bool, ##-- store shared lines (default=1)
sub saveTextFile {
  my ($diff,$file,%opts) = @_;
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  confess(ref($diff)."::saveTextFile(): open failed for '$file': $!") if (!defined($fh));
  binmode($fh,':utf8');

  ##-- options
  %opts = (header=>1,files=>1,shared=>1,%opts);

  ##-- dump: header
  $fh->print("%% -*- Mode: Diff; encoding: utf-8 -*-\n",
	     (("%" x 80), "\n"),
	     "%% File auto-generated by ", ref($diff), "\n",
	     "%% File Format:\n",
	     "%%  \% COMMENT                 : comment\n",
	     "%%  \$ NAME: VALUE             : ".ref($diff)." object data field\n",
	     "%%  \@ OP MIN1,MAX1 MIN2,MAX2  : diff hunk address (0-based)\n",
	     "%%  <\\tLINE1                  : (\"deleted\")  line from file1 missing in file2\n",
	     "%%  >\\tLINE1                  : (\"inserted\") line from file2 missing in file1\n",
	     "%%  \\tLINE                    : (\"shared\")   line in both file1 and file2\n",
	     (("%" x 80), "\n"),
	    ) if ($opts{header});

  $fh->print("\$ file1: $diff->{file1}\n",
	     "\$ file2: $diff->{file2}\n",
	    ) if ($opts{files});

  ##-- dump: sequences + hunks
  my ($i1,$i2) = (0,0);
  my ($seq1,$seq2,$hunks) = @$diff{qw(seq1 seq2 hunks)};
  my ($hunk, $op,$min1,$max1,$min2,$max2,$res, $addr);
  my $sep12 = "\t\$--\$\t";
  foreach $hunk (@{$diff->{hunks}}) {
    ($op,$min1,$max1,$min2,$max2,$res) = @$hunk;

    ##-- dump preceding context
    $fh->print(map { $diff->sharedString($seq1->[$i1+$_], $seq2->[$i2+$_]) } (0..($min1-$i1-1)))
      if ($opts{shared});

    ##-- dump hunk
    $addr = "\@ $op $min1,$max1 $min2,$max2";
    $addr .= (defined($res) ? (ref($res) ? ' :@' : " :$res") : '');
    $fh->print($addr, "\n",
	       (map {"<\t$_\n"} @$seq1[($min1+0)..($max1+0)]),
	       (map {">\t$_\n"} @$seq2[($min2+0)..($max2+0)]),
	       (ref($res) ? (map {":\t$_\n"} @$res) : qw()),
	      );

    ##-- update current position counters
    ($i1,$i2) = ($max1+1,$max2+1);
  }
  ##-- dump trailing context
  $fh->print(map { $diff->sharedString($seq1->[$i1+$_], $seq2->[$i2+$_]) } (0..($#$seq1-$i1-1)))
    if ($opts{shared});
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
  binmode($fh,':utf8');

  ##-- load
  @{$diff->{hunks}} = qw();
  @{$diff->{seq1}}  = qw();
  @{$diff->{seq2}}  = qw();
  my ($hunks,$seq1,$seq2) = @$diff{qw(hunks seq1 seq2)};
  my ($line, $hunk);
  my (@w1,@w2);
  while (defined($line=<$fh>)) {
    chomp($line);
    if    ($line =~ /^\%/) { ; }    ##-- comment
    elsif ($line =~ /^\$\s+(\w+):\s+(.*)$/) { ##-- object data field
      $diff->{$1} = $2;
    }
    elsif ($line =~ /^\@ ([acd]) (\-?\d+),(\-?\d+) (\-?\d+),(\-?\d+)(?: \: ?([\d\@]+))?$/) { ##-- hunk address
      push(@$hunks, $hunk=[$1, map {$_+0} ($2,$3,$4,$5,(defined($6) ? $6 : qw()))]);
    }
    elsif ($line =~ /^\t/) { ##-- shared sequence item
      @w1 = @w2 = qw();
      while ($line =~ /[\t\n\r]([\=\<\>])([^\t\n\r]*)/g) {
	push(@w1, $2) if ($1 ne '>');
	push(@w2, $2) if ($1 ne '<');
      }
      push(@$seq1, join("\t",@w1));
      push(@$seq2, join("\t",@w2));
    }
    elsif ($line =~ /^\<\t(.*)$/) { ##-- seq1-only item
      push(@$seq1,$1);
    }
    elsif ($line =~ /^\>\t(.*)$/) { ##-- seq2-only item
      push(@$seq2,$1);
    }
    elsif ($line =~ /^\:\t(.*)$/) { ##-- resolution item
      warn(ref($diff)."::loadTextFile($file): ignoring resolution without current hunk: '$line'") if (!$hunk);
      $hunk->[5] = [] if (!ref($hunk->[5]));
      push(@{$hunk->[5]}, $1);
    }
    else {
      warn(ref($diff)."::loadTextFile($file): parse error at line ", $fh->input_line_number, ", ignoring: '$line'");
    }
  }
  $fh->close() if (!ref($file));

  return $diff;
}


##==============================================================================
## Footer
1;

__END__
