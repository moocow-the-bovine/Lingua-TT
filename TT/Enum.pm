## -*- Mode: CPerl -*-
## File: Lingua::TT::Enum.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Descript: TT Utils: in-memory Enum


package Lingua::TT::Enum;
use Lingua::TT::IO;
use Carp;
use strict;

##==============================================================================
## Globals & Constants

our @ISA = qw();

##==============================================================================
## Constructors etc.

## $enum = CLASS_OR_OBJECT->new(%opts)
## + %opts, %$enum:
##    sym2id => \%sym2id, ##-- $sym=>$id, ...
##    id2sym => \@id2sym, ##-- $id=>$sym, ...
##    size   => $n_ids,   ##-- index of first free id
##    io     => \%opts,   ##-- I/O opts; default={encoding=>'utf8'}
sub new {
  my $that = shift;
  my $enum = bless({
		    sym2id => {},
		    id2sym => [],
		    size => 0,
		    io => {encoding=>'utf8'},
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

##--------------------------------------------------------------
## Methods: I/O: save

## $bool = $enum->save($filename_or_fh,%opts)
## + alias for $enum->saveFile()
BEGIN {
  *save = \&saveFile;
}

## $bool = $enum->saveFile($filename_or_fh,%opts)
## + %opts are passed to Lingua::TT::IO::toFile()
sub saveFile {
  my $enum = shift;
  my $io = Lingua::TT::IO->toFile($_[0],%{$enum->{io}},@_[1..$#_])
    or die(ref($enum)."::saveFile(): could not open file '$_[0]': $!");
  return $enum->saveIO($io);
}

## \$str = $enum->saveString(\$string,%opts)
## + %opts are passed to Lingua::TT::IO::toString()
sub saveString {
  my $enum = shift;
  my $io = Lingua::TT::IO->toString($_[0],%{$enum->{io}},@_[1..$#_])
    or die(ref($enum)."::saveString(): could not open string '$_[0]': $!");
  return $enum->saveIO($io);
}

## $bool = $enum->saveIO($io)
## + saves to Lingua::TT::IO object
sub saveIO {
  my ($enum,$io) = @_;
  my ($sym,$id);
  my $id2sym = $enum->{id2sym};
  my $fh = $io->{fh};
  for ($id=0; $id < $enum->{size}; $id++) {
    next if (!exists($id2sym->[$id]));
    $fh->print($id,"\t",$id2sym->[$id],"\n");
  }
  return $enum;
}

##--------------------------------------------------------------
## Methods: I/O: load

## $bool = $enum->load($filename_or_fh,%opts)
## + alias for $enum->loadFile()
BEGIN {
  *load = \&loadFile;
}

## $bool = $enum->loadFile($filename_or_fh,%opts)
## + %opts are passed to Lingua::TT::IO::toFile()
sub loadFile {
  my $enum = shift;
  my $io = Lingua::TT::IO->fromFile($_[0],%{$enum->{io}},@_[1..$#_])
    or die(ref($enum)."::loadFile(): could not open file '$_[0]': $!");
  return $enum->loadIO($io);
}

## $bool = $enum->loadString(\$string,%opts)
## + %opts are passed to Lingua::TT::IO::toString()
sub loadString {
  my $enum = shift;
  my $io = Lingua::TT::IO->loadString($_[0],%{$enum->{io}},@_[1..$#_])
    or die(ref($enum)."::loadString(): could not open string '$_[0]': $!");
  return $enum->loadIO($io);
}

## $bool = $enum->loadIO($io)
## + loads from Lingua::TT::IO object
sub loadIO {
  my ($enum,$io) = @_;
  my $id2sym = $enum->{id2sym};
  my $sym2id = $enum->{sym2id};
  my $fh = $io->{fh};
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
