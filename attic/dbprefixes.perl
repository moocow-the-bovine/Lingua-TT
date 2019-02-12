#!/usr/bin/perl -w

use DB_File;
my ($dbfile,$prefix) = @ARGV;

my $tied = tie(my %db, 'DB_File', $dbfile, O_RDONLY, 0666, $DB_BTREE)
  or die("$0: failed to tie $dbfile");

my $key  = $prefix;
my $freq = 0;
my ($val,$status);
for ($status = $tied->seq($key,$val,R_CURSOR);
     $status == 0 && $key =~ /^\Q$prefix\E/;
     $status = $tied->seq($key,$val,R_NEXT))
  {
    #print($key, "\t", $val, "\n")
    $freq += $val;
  }
print "$freq\n";


