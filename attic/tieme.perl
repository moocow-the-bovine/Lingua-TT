#!/usr/bin/perl -w

use DB_File;
use Fcntl;


my ($dbfile) = shift(@ARGV) || 'tokens.bin';
my (@data);
my $dbflags = O_RDONLY;
my $dbmode  = (0666 & ~umask);
my $dbinfo  = DB_File::RECNOINFO->new();
$dbinfo->{reclen} = 4;
$dbinfo->{flags} |= R_FIXEDLEN;
my $tied = tie(@data, 'DB_File', $dbfile, $dbflags, $dbmode, $dbinfo)
  or die("$0: tie() failed for $dbfile: $!");

my ($i);
for ($i=0; $i <= $#data && $i < 10; ++$i) {
  print "$i\t", unpack('L', $data[$i]), "\n";
}

undef $tied;
untie(@data);

