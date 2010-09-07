#!/usr/bin/perl -w

use lib qw(.);
use Lingua::TT;
use Lingua::TT::Enum;
use Lingua::TT::DB::File;
use Lingua::TT::DB::File::PackedArray;
use Fcntl;

if (!@ARGV) {
  print STDERR "Usage: $0 TTFILE [DB_BASE=TTFILE]\n";
  exit 1;
}
($ttfile,$dbbase) = @ARGV;
$dbbase = $ttfile if (!defined($dbbase));

my $io   = Lingua::TT::IO->fromFile($ttfile,encoding=>'UTF-8');
my $enum = Lingua::TT::Enum->new();
my $dbf = Lingua::TT::DB::File::PackedArray->new(packfmt=>'S',file=>"$dbbase.db",flags=>O_RDWR|O_CREAT|O_TRUNC)
  or die("$0: could not create db file $dbbase.db: $!");

my $fh = $io->{fh};
my ($line,$id);
while (defined($line=<$fh>)) {
  chomp($line);
  $id = $enum->{sym2id}{$line};
  $id = $enum->getId($line) if (!defined($id));
  $dbf->{tied}->push(pack($dbf->{packfmt},$id));
}

##-- dump enum
$enum->saveFile("$dbbase.enum")
  or die("$0: could not save '$dbbase.enum': $!");
