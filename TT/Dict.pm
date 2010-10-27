## -*- Mode: CPerl -*-
## File: Lingua::TT::Enum.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Descript: TT Utils: in-memory Enum

package Lingua::TT::Dict;
use Lingua::TT::Persistent;
use Lingua::TT::IO;
use Carp;
use strict;

##==============================================================================
## Globals & Constants

our @ISA = qw(Lingua::TT::Persistent);

##==============================================================================
## Constructors etc.

## $dict = CLASS_OR_OBJECT->new(%opts)
## + %opts, %$dict:
##    dict => \%key2val,  ##-- dict data
sub new {
  my $that = shift;
  my $dict = bless({
		    dict=>{},
		    @_
		   }, ref($that)||$that);
  return $dict;
}

## undef = $dict->clear()
sub clear {
  my $dict = shift;
  %{$dict->{dict}} = qw();
  return $dict;
}

##==============================================================================
## Methods: Access and Manipulation

## $n_keys = $dict->size()
sub size {
  return scalar CORE::keys %{$_[0]{dict}};
}

## @keys = $dict->keys()
sub keys {
  return CORE::keys %{$_[0]{dict}};
}

## $val = $dict->get($key)
sub get {
  return $_[0]{dict}{$_[1]};
}

##==============================================================================
## Methods: I/O

##--------------------------------------------------------------
## Methods: I/O: Native

## $bool = $dict->saveNativeFh($fh,%opts)
## + saves to filehandle
## + %opts
##    encoding => $enc,  ##-- sets $fh :encoding flag if defined; default: none
sub saveNativeFh {
  my ($dict,$fh,%opts) = @_;
  binmode($fh,":encoding($opts{encoding})") if (defined($opts{encoding}));
  my ($key,$val);
  while (($key,$val)=each(%{$dict->{dict}})) {
    $fh->print($key, "\t", $val, "\n");
  }
  return $dict;
}

## $bool = $dict->loadNativeFh($fh)
## + loads from handle
## + %opts
##    encoding => $enc,  ##-- sets $fh :encoding flag if defined; default: none
sub loadNativeFh {
  my ($dict,$fh,%opts) = @_;
  binmode($fh,":encoding($opts{encoding})") if (defined($opts{encoding}));
  $dict = $dict->new() if (!ref($dict));
  my $dh = $dict->{dict};
  my ($line,$key,$val);
  while (defined($line=<$fh>)) {
    chomp($line);
    next if ($line =~ /^\s*$/ || $line =~ /^%%/);
    ($key,$val) = split(/\t/,$line,2);
    next if (!defined($val)); ##-- don't store keys for undef values (but do for empty string)
    $dh->{$key} = $val;
  }
  return $dict;
}

##--------------------------------------------------------------
## Methods: I/O: Bin

## ($serialized_string,\@other_refs) = STORABLE_freeze($obj, $cloning_flag)

## $obj = STORABLE_thaw($obj, $cloning_flag, $serialized_string, @other_refs)

##==============================================================================
## Footer
1;

__END__
