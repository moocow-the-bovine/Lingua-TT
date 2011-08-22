## -*- Mode: CPerl -*-
## File: Lingua::TT::CDBFile.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Descript: TT I/O: CDB: tied read-only access via CDB_File

package Lingua::TT::CDBFile;
use Lingua::TT::Persistent;
use CDB_File;
use Carp;
use IO::File;
use Encode qw(encode decode);
use strict;

##==============================================================================
## Globals & Constants

our @ISA = qw(Lingua::TT::Persistent);

##==============================================================================
## Constructors etc.

## $dbf = CLASS_OR_OBJECT->new(%opts)
## + %opts, %$doc:
##   ##-- user options
##   file     => $filename,    ##-- default: undef (none)
##   tmpfile  => $tmpfilename, ##-- defualt: "$filename.$$" (not used correctly due to CDB_File bug)
##   mode     => $mode,        ##-- open mode 'r', 'w', 'rw', '<', '>', '>>': default='r'
##   encoding => $enc,         ##-- if defined, $enc will be used to store db data (uses Encode); default=undef (raw bytes)
##   ##
##   ##-- low-level data
##   data   => \%data,         ##-- tied data (hash)
##   tied   => $ref,           ##-- read-only: reference returned by tie()
##   writer => $ref,           ##-- read/write: reference returned by CDB_File::new()
sub new {
  my $that = shift;
  my $dbf = bless({
		   file    => undef,
		   tmpfile => undef,
		   mode    => 'r',
		   encoding => undef,
		   ##
		   data   => undef,
		   tied   => undef,
		   @_
		  }, ref($that)||$that);
  return $dbf->open($dbf->{file}) if (defined($dbf->{file}));
  return $dbf;
}

## undef = $dbf->clear()
##  + clears data (if any)
sub clear {
  my $dbf = shift;
  return if (!$dbf->opened);
  %{$dbf->{data}} = qw();
  return $dbf;
}


##==============================================================================
## Methods: low-level utilities

##==============================================================================
## Methods: I/O

## $bool = $dbf->opened()
sub opened {
  return (defined($_[0]{tied}) || defined($_[0]{writer}));
}

## $dbf = $dbf->close()
sub close {
  my $dbf = shift;
  return $dbf if (!$dbf->opened);
  $dbf->{writer}->finish() if ($dbf->{writer});
  if (defined($dbf->{tied})) {
    $dbf->{tied} = undef;
    untie(%{$dbf->{data}});
  }
  return $dbf;
}

## $dbf = $dbf->open($file,%opts)
##  + %opts are as for new()
##  + $file defaults to $dbf->{file}
sub open {
  my ($dbf,$file,%opts) = @_;
  $dbf->close() if ($dbf->opened);
  @$dbf{keys %opts} = values(%opts);
  $file           = $dbf->{file} if (!defined($file));
  $dbf->{file}    = $file;
  $dbf->{tmpfile} = "$file.$$" if (!defined($dbf->{tmpfile}));

  ##-- truncate file here if user requested it
  if ($dbf->{mode} =~ /^[\+r]*[>w]$/) {
    $dbf->truncate()
      or confess(ref($dbf)."::open(): could not truncate file '$dbf->{file}': $!");
  }

  ##-- tie data hash
  delete(@$dbf{qw(writer data tied)});
  if ($dbf->{mode} =~ /[\+w>]/) {
    $dbf->{writer} = CDB_File->new($dbf->{file}, $dbf->{tmpfile})
      or confess(ref($dbf)."::open(): CDB_File->new() failed for '$dbf->{file}': $!");
  }
  if ($dbf->{mode} =~ /[\+r<]/) {
    $dbf->{data} = {};
    $dbf->{tied} = tie(%{$dbf->{data}}, __PACKAGE__."::Tied", $dbf->{file}, $dbf->{encoding}) #$dbf->{tmpfile}
      or confess(ref($dbf).":open(): could not tie CDB_File for file '$dbf->{file}': $!");
  }

  return $dbf;
}

## $bool = $dbf->truncate()
## $bool = $CLASS_OR_OBJ->truncate($file)
##  + actually calls unlink($file)
##  + no-op if $file and $dbf->{file} are both undef
sub truncate {
  my ($dbf,$file) = @_;
  $file = $dbf->{file} if (!defined($file));
  return if (!defined($file));
  !-e $file || unlink($file) || return undef;
}

## $bool = $dbf->sync()
## $bool = $dbf->sync($flags)
sub sync {
  my $dbf = shift;
  return 1 if (!$dbf->opened);
  return $dbf->close() && $dbf->open() ? 1 : 0;
}

## $bool = $dbf->copy($file2)
## $bool = PACKAGE::copy($file1,$file2)
##  + copies database data to $file2
sub copy {
  confess(ref($_[0])."::copy() not implemented");
}

##==============================================================================
## Methods: TT::Persistent

## @keys = $dbf->noSaveKeys()
sub noSaveKeys {
  return qw(data tied writer);
}

################################################################################
package Lingua::TT::CDBFile::Tied;
use CDB_File;
use Encode qw(encode decode);
use Carp;
use strict;

## $tied = TIEHASH($classname, $cdbfile, $encoding)
##  + $tied = [$cdb_tied,\&fetch_filter,\&store_filter]
sub TIEHASH {
  my ($that,$file,$enc) = @_;
  my $tied0 = CDB_File->TIEHASH($file) or return undef;
  $enc      = '' if (!defined($enc) || $enc eq 'raw' || $enc eq 'bytes' || $enc eq 'null');
  return bless([$tied0,$enc], ref($that)||$that);
}

sub FETCH {
  return CDB_File::FETCH($_[0][0], $_[1]) if (!$_[0][1]);
  return decode($_[0][1],CDB_File::FETCH($_[0][0], (utf8::is_utf8($_[1]) ? encode($_[0][1],$_[1]) : $_[1])));
}
sub STORE {
  return CDB_File::STORE($_[0][0], $_[1], $_[2]) if (!$_[0][1]);
  return CDB_File::STORE($_[0][0], (utf8::is_utf8($_[1]) ? encode($_[0][1],$_[1]) : $_[1]), (utf8::is_utf8($_[2]) ? encode($_[0][1],$_[2]) : $_[2]));
}
sub DELETE {
  return CDB_File::DELETE($_[0][0], $_[1]) if (!$_[0][1]);
  return decode($_[0][1],CDB_File::DELETE($_[0][0], (utf8::is_utf8($_[1]) ? encode($_[0][1],$_[1]) : $_[1])));
}
sub EXISTS {
  return CDB_File::EXISTS($_[0][0], $_[1]) if (!$_[0][1]);
  return CDB_File::EXISTS($_[0][0], (utf8::is_utf8($_[1]) ? encode($_[0][1],$_[1]) : $_[1]));
}
sub FIRSTKEY {
  CDB_File::FIRSTKEY($_[0][0]);
}
sub NEXTKEY {
  return CDB_File::NEXTKEY($_[0][0], $_[1]) if (!$_[0][1]);
  return CDB_File::NEXTKEY($_[0][0], (utf8::is_utf8($_[1]) ? encode($_[0][1],$_[1]) : $_[1]));
}

#sub SCALAR { CDB_File::SCALAR($_[0][0]); }
#sub CLEAR { CDB_File::CLEAR($_[0][0]); }
sub UNTIE { $_[0][0]=undef; }


##==============================================================================
## Footer
1;

__END__
