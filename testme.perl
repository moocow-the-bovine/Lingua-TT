#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Benchmark qw(cmpthese timethese);
use Encode qw(encode decode);

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

  my $sent3 = Lingua::TT::Sentence->new(map {Lingua::TT::Token->new($_)} qw(`` foo),',',qw('' said he; I 'm done .));
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
#test_tt_diff(@ARGV);

##----------------------------------------------------------------------
use DB_File;
use Fcntl;
sub test_db_recno {
  my $ttfile = @_ ? shift : 'test1.t';
  my (@recs);
  my $rt = tie(@recs, 'DB_File', $ttfile, O_RDONLY, 0644, $DB_RECNO)
    or die("$0: tie() failed for $ttfile: $!");
  foreach (@recs) {
    print $_, "\n";
  }
  ##-- cleanup
  undef $rt;
  untie @recs;
}
#test_db_recno(@ARGV);

##----------------------------------------------------------------------
use Lingua::TT::DB::Enum;
sub test_db_enum_0 {
  my $efile = @_ ? shift : 'enum';
  my $dbe = Lingua::TT::DB::Enum->new(file=>$efile);

  my $i1 = $dbe->getId('foo');
  my $i2 = $dbe->getId('bar');
  my $i3 = $dbe->getId('baz');

  my $s1 = $dbe->getSym($i1);
  my $s2 = $dbe->getSym($i2);
  my $s3 = $dbe->getSym($i3);

  $dbe->close();
}
#test_db_enum(@ARGV);

sub test_db_enum_create {
  my $which = @_ ? shift : '_HR';
  #my $which = '';
  my $tfile = @_ ? shift : 'tiger.utf8.orig.t';
  my $efile = @_ ? shift : "enum${which}";

  my $io = Lingua::TT::IO->open('<',$tfile)
    or die("open failed for '$tfile': $!");
  require "Lingua/TT/DB/Enum${which}.pm";
  my $dbe = "Lingua::TT::DB::Enum${which}"->new(file=>$efile, flags=>(O_RDWR|O_CREAT|O_TRUNC))
    or die("open failed for '$efile': $!");
  $dbe->clear();

  my $fh = $io->{fh};
  my ($text);
  while (defined($text=<$fh>)) {
    chomp($text);
    $text =~ s/\t.*$//;
    next if ($text eq '' || $text =~ /^\%\%/);
    $dbe->getId($text) if (!exists($dbe->{sym2id}{$text}));
  }
  $dbe->close;
  $fh->close;
  $io->close;
  exit 0;
}
#test_db_enum_create(@ARGV);

sub test_db_enum_apply {
  my $which = @_ ? shift : '_HH'; #'_HR';
  #my $which = '';
  my $tfile = @_ ? shift : 'tiger.utf8.orig.t';
  my $efile = @_ ? shift : "enum${which}";
  my $ofile = @_ ? shift : "out${which}.t";

  my $io = Lingua::TT::IO->open('<',$tfile)
    or die("open failed for '$tfile': $!");
  require "Lingua/TT/DB/Enum${which}.pm";
  my $dbe = "Lingua::TT::DB::Enum${which}"->new(file=>$efile, flags=>(O_RDWR|O_CREAT)) #|O_TRUNC
    or die("open failed for '$efile': $!");
  #$dbe->clear();
  my $outfh = IO::File->new(">$ofile") or die("$0: open failed for '$ofile': $!");
  $outfh->binmode(':utf8');

  my $infh = $io->{fh};
  my ($text,$id);
  while (defined($text=<$infh>)) {
    chomp($text);
    $text =~ s/\t.*$//;
    if ($text eq '' || $text =~ /^\%\%/) {
      $outfh->print($text,"\n");
      next;
    }
    $id = $dbe->{sym2id}{$text};
    $outfh->print($id,"\t",$text,"\n");
  }
  $dbe->close;
  $infh->close;
  $outfh->close;
  $io->close;
  exit 0;
}
#test_db_enum_apply(@ARGV);

sub test_db_enum_apply2 {
  my $which = @_ ? shift : '_HH'; #'_HR';
  #my $which = '';
  my $tfile = @_ ? shift : 'tiger.utf8.orig.t';
  my $efile = @_ ? shift : "enum${which}";
  my $ofile = @_ ? shift : "out2${which}.t";

  my $io = Lingua::TT::IO->open('<',$tfile)
    or die("open failed for '$tfile': $!");
  require "Lingua/TT/DB/Enum${which}.pm";
  my $dbe = "Lingua::TT::DB::Enum${which}"->new(file=>$efile, flags=>(O_RDWR|O_CREAT)) #|O_TRUNC
    or die("open failed for '$efile': $!");
  #$dbe->clear();
  my $outfh = IO::File->new(">$ofile") or die("$0: open failed for '$ofile': $!");
  $outfh->binmode(':utf8');

  my $infh = $io->{fh};
  my ($text,$id,$text2);
  while (defined($text=<$infh>)) {
    chomp($text);
    $text =~ s/\t.*$//;
    if ($text eq '' || $text =~ /^\%\%/) {
      $outfh->print($text,"\n");
      next;
    }
    $id    = $dbe->{sym2id}{$text};
    $text2 = (ref($dbe->{id2sym}) eq 'ARRAY'
	      ? $dbe->{id2sym}[$id]
	      : $dbe->{id2sym}{$id});
    $outfh->print($id,"\t",$text2,"\n");
  }
  $dbe->close;
  $infh->close;
  $outfh->close;
  $io->close;
  exit 0;
}
#test_db_enum_apply2(@ARGV);


##----------------------------------------------------------------------
use Lingua::TT::Enum;
sub test_enum {
  my $enum = Lingua::TT::Enum->new();

  my $i1 = $enum->getId('foo');
  my $i2 = $enum->getId('bar');
  my $i3 = $enum->getId('baz');
  my $i4 = $enum->getId("\x{17f}oobar");

  my $s1 = $enum->getSym($i1);
  my $s2 = $enum->getSym($i2);
  my $s3 = $enum->getSym($i3);
  my $s4 = $enum->getSym($i4);

  my $estr = '';
  $enum->saveString(\$estr);
  $enum->saveFile('enum.dat');
  print STDERR "test_enum(): done\n";
}
#test_enum();

##----------------------------------------------------------------------
use Lingua::TT::DB::File::PackedArray;
sub test_packedarray {
  my $af = @_ ? shift : 'pa.db';

  my $pa = Lingua::TT::DB::File::PackedArray->new(packfmt=>'L',file=>$af,flags=>O_RDWR|O_CREAT|O_TRUNC);
  my @vals = map {[$_]} qw(1 2 3 42);
  $pa->ppush(@$_) foreach (@vals);
  $pa->close;

  ##-- re-open
  $pa->open($af,flags=>O_RDONLY);
  my @ovals = map {$pa->rget($_)} (0..$#{$pa->{data}});

  print STDERR "test_packedarray: done()";
}
#test_packedarray(@ARGV);

##----------------------------------------------------------------------
use Lingua::TT::DB::Document;
sub test_db_doc {
  my $dir = 'dbdoc';

  my $dbdoc = Lingua::TT::DB::Document->new(dir=>$dir,truncate=>1);
  $dbdoc->sync();

  my $str  = $dbdoc->savePerlString;
  my $doc2 = Lingua::TT::DB::Document->loadPerlString($str);
  $doc2->open($dir,truncate=>0,nocreate=>1);

  print STDERR "test_db_doc(): done\n";
}
#test_db_doc();

sub test_db_doc_put {
  my $file = @_ ? shift : 'negra.utf8.tt';
  my $dir  = @_ ? shift : "$file.db";

  #my $dbdoc = Lingua::TT::DB::Document->new(dir=>$dir,truncate=>1);
  my $dbdoc = Lingua::TT::DB::Document->new(dir=>$dir,truncate=>1,
					    fields=>[{name=>'text',get=>'$_->[0]'},
						     {name=>'tag', get=>'$_->[1]',packfmt=>'C'},
						    ]);
  my $io    = Lingua::TT::IO->fromFile($file);
  $dbdoc->putIO($io);
  $dbdoc->sync();

  print STDERR "test_db_doc(): done\n";
  exit 0;
}
#test_db_doc_put(@ARGV);

##----------------------------------------------------------------------
## ($tied,\@ttlines) = db_ttrec($file)
sub tt_dba {
  my $ttfile = shift;
  my @ttlines = qw();
  my $dbinfo = DB_File::RECNOINFO->new;
  $dbinfo->{cachesize} = 1024**3;
  my $tied = tie(@ttlines, 'DB_File', $ttfile, O_RDWR, 0644, $dbinfo)
    or die("$0: tt_dba(): tie() failed for $ttfile: $!");
  return wantarray ? ($tied,\@ttlines) : \@ttlines;
}

sub bench_dbdoc_get {
  my $ttfile = @_ ? shift : 'negra.utf8.clean.t';
  my $dbdir  = @_ ? shift : "$ttfile.db";

  ##-- data
  my ($tied,$tta) = tt_dba($ttfile);
  my  $dbd = Lingua::TT::DB::Document->new(dir=>$dbdir,truncate=>0,
					   fields=>[{name=>'text',get=>'$_->[0]'},
						    {name=>'tag', get=>'$_->[1]',packfmt=>'C'},
						   ]);

  ##-- access subs
  my $tta_getline = sub { $tta->[$_[0]] };
  my $dbd_getline = sub { join("\t",
			       map {
				 $_->{enum}{id2sym}[unpack($_->{packfmt},$_->{data}[$_[0]])]
			       } @{$dbd->{fields}}
			      )
			    };
  my $tta_gettxt = sub { (split(/\t/,$tta->[$_[0]]))[0] };
  my $f  = $dbd->{fields}[0];
  my $dbd_gettxt = sub { $f->{enum}{id2sym}[unpack($f->{packfmt},$f->{data}[$_[0]])] };


  ##-- debug
  my $tta_l0 = $tta_getline->(0);
  my $dbd_l0 = $dbd_getline->(0);
  my $tta_x0 = $tta_gettxt->(0);
  my $dbd_x0 = $dbd_gettxt->(0);

  ##-- test: which
  my %test = (
	      #'seq:line'=>1,
	      #'seq:text'=>1,
	      #'rand:line'=>1,
	      'rand:text'=>1,
	     );

  my @ids = (0..$#{$dbd->{fields}[0]{data}});
  if ($test{'seq:line'}) {
    print STDERR "BENCH: seq: line\n";
    cmpthese(1,{
		'seq:tta:line' => sub { $tta_getline->($_) foreach (@ids); },
		'seq:dbd:line' => sub { $dbd_getline->($_) foreach (@ids); },
	       })
  }
  if ($test{'seq:text'}) {
    print STDERR "BENCH: seq: text\n";
    cmpthese(1,{
		'seq:tta:text' => sub { $tta_gettxt->($_) foreach (@ids); },
		'seq:dbd:text' => sub { $dbd_gettxt->($_) foreach (@ids); },
	       });
  }

  ##-- randomize ids
  foreach $i (0..$#ids) {
    $j = int(rand($#ids+1));
    @ids[$i,$j] = @ids[$j,$i];
  }
  if ($test{'rand:line'}) {
    print STDERR "BENCH: rand: line\n";
    cmpthese(1,{
		'rand:tta:line' => sub { $tta_getline->($_) foreach (@ids); },
		'rand:dbd:line' => sub { $dbd_getline->($_) foreach (@ids); },
	       });
  }
  if ($test{'rand:text'}) {
    print STDERR "BENCH: rand: text\n";
    cmpthese(1,{
		'rand:tta:text' => sub { $tta_gettxt->($_) foreach (@ids); },
		'rand:dbd:text' => sub { $dbd_gettxt->($_) foreach (@ids); },
	       });
  }

  print STDERR "$0: bench_dbdoc_get(): done.\n";
  exit 0;
}
bench_dbdoc_get(@ARGV);

##======================================================================
## MAIN (dummy)
foreach $i (1..3) {
  print STDERR "$0: dummy[$i]\n";
}
