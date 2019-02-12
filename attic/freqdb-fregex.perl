#!/usr/bin/perl -w

use DB_File;
my ($dbfile,$regex) = @ARGV;

my $tied = tie(my %db, 'DB_File', $dbfile, O_RDONLY, 0666, $DB_BTREE)
  or die("$0: failed to tie $dbfile");

my $freq = 0;
my ($key,$val,$status);
for ($status = $tied->seq($key,$val,R_FIRST);
     $status == 0;
     $status = $tied->seq($key,$val,R_NEXT))
  {
    $freq += $val if ($key =~ m{$regex}o);
  }
print "$freq\n";
