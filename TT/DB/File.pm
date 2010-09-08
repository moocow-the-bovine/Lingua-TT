## -*- Mode: CPerl -*-
## File: Lingua::TT::DB::File.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Descript: TT I/O: Berkely DB: tied Files


package Lingua::TT::DB::File;
use Lingua::TT::Persistent;
use DB_File;
use Fcntl;
use Carp;
use IO::File;
use File::Copy qw();
use strict;

##==============================================================================
## Globals & Constants

our @ISA = qw(Lingua::TT::Persistent);

##==============================================================================
## Constructors etc.

## $dbf = CLASS_OR_OBJECT->new(%opts)
## + %opts, %$doc:
##   ##-- user options
##   file  => $directory,  ##-- default: undef (none)
##   mode  => $mode,       ##-- default: 0644
##   flags => $flags,      ##-- default: O_RDWR|O_CREAT
##   type    => $type,     ##-- one of 'HASH', 'BTREE', 'RECNO' (default: 'HASH')
##   dbinfo  => \%dbinfo,  ##-- default: "DB_File::${type}INFO"->new();
##   dbopts  => \%opts,    ##-- db options (e.g. cachesize,bval,...) -- defaults to none (uses DB_File defaults)
##   ##
##   ##-- low-level data
##   data   => $thingy,    ##-- tied data (hash or array)
##   tied   => $ref,       ##-- reference returned by tie()
sub new {
  my $that = shift;
  my $db = bless({
		  file   => undef,
		  mode   => 0644,
		  flags  => (O_RDWR|O_CREAT),
		  type   => 'hash',
		  dbinfo => undef,
		  dbopts => {},
		  data   => undef,
		  tied   => undef,
		  @_
		 }, ref($that)||$that);
  $db->{dbinfo} = ("DB_File::".uc($db->{type})."INFO")->new() if (!defined($db->{dbinfo}));
  return $db->open($db->{file}) if (defined($db->{file}));
  return $db;
}

## undef = $dbf->clear()
##  + clears data (if any)
sub clear {
  my $dbf = shift;
  return if (!$dbf->opened);
  if (uc($dbf->{type}) eq 'RECNO') {
    $dbf->{tied}->splice(0,scalar(@{$dbf->{data}}));
  } else {
    %{$dbf->{data}} = qw();
  }
  return $dbf;
}

##==============================================================================
## Methods: low-level utilities

##==============================================================================
## Methods: I/O

## $bool = $dbf->opened()
sub opened {
  return defined($_[0]{tied});
}

## $dbf = $dbf->close()
sub close {
  my $dbf = shift;
  return $dbf if (!$dbf->opened);
  $dbf->{tied} = undef;
  if (uc($dbf->{type}) eq 'RECNO') {
    untie(@{$dbf->{data}});
  } else {
    untie(%{$dbf->{data}});
  }
  return $dbf;
}

## $dbf = $dbf->open($file,%opts)
##  + %opts are as for new()
sub open {
  my ($dbf,$file,%opts) = @_;
  $dbf->close() if ($dbf->opened);
  $dbf->{file} = $file;
  @$dbf{keys %opts} = values(%opts);
  @{$dbf->{dbinfo}}{keys %{$dbf->{dbopts}}} = values %{$dbf->{dbopts}};

  ##-- truncate file here if user specified O_TRUNC, since DB_File doesn't
  if (($dbf->{flags} & O_TRUNC) && -e $dbf->{file}) {
    unlink($dbf->{file})
      or confess(ref($dbf)."::open(O_TRUNC): could not unlink file '$dbf->{file}': $!");
  }

  if (uc($dbf->{type}) eq 'RECNO') {
    ##-- tie: recno (array)
    $dbf->{data} = [];
    $dbf->{tied} = tie(@{$dbf->{data}}, 'DB_File', $dbf->{file}, $dbf->{flags}, $dbf->{mode}, $dbf->{dbinfo})
      or confess(ref($dbf).":open(): tie() failed for ARRAY file '$dbf->{file}': $!");
  } else {
    ##-- tie: btree or hash (hash)
    $dbf->{data} = {};
    $dbf->{tied} = tie(%{$dbf->{data}}, 'DB_File', $dbf->{file}, $dbf->{flags}, $dbf->{mode}, $dbf->{dbinfo})
      or confess(ref($dbf).":open(): tie() failed for HASH file '$dbf->{file}': $!");
  }

  return $dbf;
}

## $bool = $dbf->sync()
## $bool = $dbf->sync($flags)
sub sync {
  my $dbf = shift;
  return 1 if (!$dbf->opened);
  return $dbf->{tied}->sync(@_) == 0;
}

## $bool = $dbf->copy($file2)
## $bool = PACKAGE::copy($file1,$file2)
##  + copies database data to $file2
sub copy {
  my ($dbf,$file2) = @_;
  my $that  = ref($dbf) || __PACKAGE__;
  my $file1 = ref($dbf) ? $dbf->{file} : $dbf;
  confess("${that}::copy(): no source specified!") if (!defined($file1));
  confess("${that}::copy(): no destination specified!") if (!defined($file2));
  if (ref($dbf)) { $dbf->sync() or confess("${that}::copy(): sync failed: $!"); }
  File::Copy::copy($file1, $file2)
      or confess("${that}::copy() failed from '$file1' to '$file2': $!");
  return 1;
}

##==============================================================================
## Methods: TT::Persistent

## @keys = $dbf->noSaveKeys()
sub noSaveKeys {
  return qw(dbinfo dbopts data tied);
}

##==============================================================================
## Footer
1;

__END__
