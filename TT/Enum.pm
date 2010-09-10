## -*- Mode: CPerl -*-
## File: Lingua::TT::Enum.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Descript: TT Utils: in-memory Enum


package Lingua::TT::Enum;
use Lingua::TT::Persistent;
use Carp;
use strict;

##==============================================================================
## Globals & Constants

our @ISA = qw(Lingua::TT::Persistent);

##==============================================================================
## Constructors etc.

## $enum = CLASS_OR_OBJECT->new(%opts)
## + %opts, %$enum:
##    sym2id => \%sym2id, ##-- $sym=>$id, ...
##    id2sym => \@id2sym, ##-- $id=>$sym, ...
##    size   => $n_ids,   ##-- index of first free id
##    io     => \%opts,   ##-- I/O opts; default={encoding=>'utf8'}
##    maxid  => $max,     ##-- maximum allowable id, e.g. 2**16-1, 2**32-1, (default=undef: no max)
sub new {
  my $that = shift;
  my $enum = bless({
		    sym2id => {},
		    id2sym => [],
		    size => 0,
		    io => {encoding=>'utf8'},
		    maxid => undef,
		    @_
		   }, ref($that)||$that);
  return $enum;
}

## undef = $enum->clear()
sub clear {
  my $enum = shift;
  %{$enum->{sym2id}} = qw();
  @{$enum->{id2sym}} = qw();
  $enum->{size} = 0;
  return $enum;
}

##==============================================================================
## Methods: Access and Manipulation

## $id = $dbe->getId($sym)
##  + gets (possibly new) id for $sym
sub getId {
  return $_[0]{sym2id}{$_[1]} if (exists($_[0]{sym2id}{$_[1]}));
  confess(ref($_[0])."::getId(): maxid=$_[0]{maxid} exceeded!") ##-- check for overflow
    if (defined($_[0]{maxid}) && $_[0]{size}==$_[0]{maxid});
  $_[0]{id2sym}[$_[0]{size}] = $_[1];
  return $_[0]{sym2id}{$_[1]} = $_[0]{size}++;
}

## $id = $dbe->getSym($id)
##  + gets (possibly new (and if so, "SYM${i}")) symbol for $id
sub getSym {
  return $_[0]{id2sym}[$_[1]] if ($_[1] < $_[0]{size});
  $_[0]{sym2id}{"SYM$_[1]"} = $_[1];
  return $_[0]{id2sym}[$_[1]] = "SYM$_[1]";
}

##==============================================================================
## Methods: I/O

## $bool = $enum->saveNativeFh($fh,%opts)
## + saves to filehandle
## + implicitly sets $fh ':utf8' flag unless $opts{raw} is set
sub saveNativeFh {
  my ($enum,$fh,%opts) = @_;
  if (!$opts{raw}) {
    CORE::binmode($fh,$opts{encoding} ? ":encoding($opts{encoding})" : ':utf8');
  }
  my ($sym,$id);
  my $id2sym = $enum->{id2sym};
  for ($id=0; $id < $enum->{size}; $id++) {
    next if (!exists($id2sym->[$id]));
    $fh->print($id,"\t",$id2sym->[$id],"\n");
  }
  return $enum;
}

## $bool = $enum->loadNativeFh($fh)
## + loads from handle
## + implicitly sets $fh ':utf8' flag unless $opts{raw} is set
sub loadNativeFh {
  my ($enum,$fh,%opts) = @_;
  if (!$opts{raw}) {
    CORE::binmode($fh,$opts{encoding} ? ":encoding($opts{encoding})" : ':utf8');
  }
  my $id2sym = $enum->{id2sym};
  my $sym2id = $enum->{sym2id};
  my ($line,$id,$sym);
  while (defined($line=<$fh>)) {
    chomp($line);
    next if ($line =~ /^\s*$/ || $line =~ /^%%/);
    ($id,$sym) = split(/\t/,$line,2);
    $id2sym->[$id]  = $sym;
    $sym2id->{$sym} = $id;
  }
  $enum->{size} = scalar(@$id2sym);
  return $enum;
}

##==============================================================================
## Footer
1;

__END__
