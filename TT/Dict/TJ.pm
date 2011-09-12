## -*- Mode: CPerl -*-
## File: Lingua::TT::Dict::TJ.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Descript: TT Utils: dictionary: TJ

package Lingua::TT::Dict::TJ;
use Lingua::TT::Dict;
use Lingua::TT::IO;
use JSON::XS;
use Carp;
use strict;

##==============================================================================
## Globals & Constants

our @ISA = qw(Lingua::TT::Dict);

##==============================================================================
## Constructors etc.

## $dict = CLASS_OR_OBJECT->new(%opts)
## + %opts, %$dict:
##    dict => \%key2val,  ##-- dict data; values here are json-encoded
sub new {
  my $that = shift;
  return $that->SUPER::new(@_);
}

##==============================================================================
## Methods: Access and Manipulation

## $jxs = $obj->jsonxs()
sub jsonxs {
  return $_[0]{jxs} if (ref($_[0]) && defined($_[0]{jxs}));
  return $_[0]{jxs} = JSON::XS->new->utf8(0);
}

##==============================================================================
## Methods: merge

## $dict = $dict->merge($dict2, %opts)
##  + include $dict2 entries in $dict, destructively alters $dict
##  + %opts:
##     append => $bool,  ##-- if true, $dict2 values are appended (dict clobber) to $dict1 values
sub merge {
  my ($d1,$d2,%opts) = @_;
  if (!$opts{append}) {
    @{$d1->{dict}}{CORE::keys %{$d2->{dict}}} = CORE::values %{$d2->{dict}}; ##-- clobber
  } else {
    my $h1 = $d1->{dict};
    my $h2 = $d2->{dict};
    my $jxs = $d1->jsonxs;
    my ($key,$sval1,$sval2,$val1,$val2);
    while (($key,$sval2)=each %$h2) {
      if (!defined($sval1=$h1->{$key})) {
	$h1->{$key} = $sval2;
      } else {
	$val1 = $jxs->decode($sval1);
	$val2 = $jxs->decode($sval2);
	if (ref($val1) eq 'HASH' && ref($val2) eq 'HASH') {
	  @$val1{keys %$val2} = values %$val2;
	}
	elsif (ref($val1) eq 'ARRAY' && ref($val2) eq 'ARRAY') {
	  push(@$val1, @$val2);
	}
	else {
	  warn("cannot merge values $val1, $val2");
	  $h1->{$key} = $sval2;
	  next;
	}
	$h1->{$key} = $jxs->encode($val1);
      }
    }
  }
  return $d1;
}


##==============================================================================
## Methods: I/O

##--------------------------------------------------------------
## Methods: I/O: generic

## $bool = $dict->setFhLayers($fh,%opts)
sub setFhLayers {
  binmode($_[1],':utf8');
}

##--------------------------------------------------------------
## Methods: I/O: Native

## $bool = $dict->saveNativeFh($fh,%opts)
## + saves to filehandle
## + %opts: (none)
sub saveNativeFh {
  my ($dict,$fh,%opts) = @_;
  binmode($fh,":utf8");
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
  binmode($fh,":utf8");
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
