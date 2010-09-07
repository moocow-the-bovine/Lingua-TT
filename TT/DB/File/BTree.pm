## -*- Mode: CPerl -*-
## File: Lingua::TT::DB::File::BTree.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Descript: TT I/O: Berkely DB: tied files: arrays (using RECNO)


package Lingua::TT::DB::File::BTree;
use Lingua::TT::DB::File;
use Carp;
use strict;

##==============================================================================
## Globals & Constants

our @ISA = qw(Lingua::TT::DB::File);

##==============================================================================
## Constructors etc.

## $dbf = CLASS_OR_OBJECT->new(%opts)
## + %opts, %$doc:
##   ##-- overrides
##   type    => $type,     ##-- one of 'HASH', 'BTREE', 'RECNO' (default: 'BTREE')
##   ##
##   ##-- user options
##   file  => $directory,  ##-- default: undef (none)
##   mode  => $mode,       ##-- default: 0644
##   flags => $flags,      ##-- default: O_RDWR|O_CREAT
##   type    => $type,     ##-- one of 'HASH', 'BTREE', 'RECNO' (default: 'BTREE')
##   dbinfo  => \%dbinfo,  ##-- default: "DB_File::${type}INFO"->new();
##   dbopts  => \%opts,    ##-- db options (e.g. cachesize,bval,...) -- defaults to none (uses DB_File defaults)
##   ##
##   ##-- low-level data
##   data   => $thingy,    ##-- tied data (hash or array)
##   tied   => $ref,       ##-- reference returned by tie()
sub new {
  my $that = shift;
  return $that->SUPER::new(type=>'BTREE',@_);
}


##==============================================================================
## Footer
1;

__END__
