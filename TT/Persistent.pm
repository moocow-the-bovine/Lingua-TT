## -*- Mode: CPerl -*-
##
## File: Lingua::TT::Persistent.pm
## Author: Bryan Jurish <jurish@uni-potsdam.de>
## Description: abstract class for persistent & configurable objects

package Lingua::TT::Persistent;
#use Lingua::TT::Logger;
use Lingua::TT::Unify;
use Lingua::TT::IO;

use Data::Dumper;
use Storable;
use IO::File;
use Carp;
use overload;
use strict;

##==============================================================================
## Globals
##==============================================================================

our @ISA = qw();

BEGIN {
  *isa = \&UNIVERSAL::isa;
  *can = \&UNIVERSAL::can;
}

##==============================================================================
## Constructors etc.
##==============================================================================

## $obj = CLASS_OR_OBJ->new(%args)
##  + object structure: (assumed to be HASH ref, other references should be OK
##    with appropritate method overrides
sub new {
  my $that = shift;
  return bless {@_}, ref($that)||$that;
}

## $obj = $obj->clone()
##  + deep clone
sub clone {
  #storable_push({Eval=>1,Deparse=>1});
  my $clone = Storable::dclone($_[0]);
  #storable_pop();
  return $clone;
}

## @STORABLE_STACK
##  + state variables (HASH-refs) for Storable module
our @STORABLE_STACK = qw();

## \%vars = CLASS_OR_OBJ->storable_push()
## \%vars = CLASS_OR_OBJ->storable_push(\%vars)
##  + pushes old Storable state vars onto @STORABLE_STACK, & sets current \%vars
sub storable_push {
  no strict 'refs';
  my $vars = shift;
  $vars = {Deparse=>1,Eval=>1} if (!$vars);
  push(@STORABLE_STACK, {Deparse=>$Storable::Deparse,Eval=>$Storable::Eval});
  ${"Storable::$_"} = $vars->{$_} foreach (keys %$vars);
  return $vars;
}

## \%vars = CLASS_OR_OBJ->storable_pop()
##  + pops Storable state vars from @STORABLE_STACK
sub storable_pop {
  no strict 'refs';
  return if (!@STORABLE_STACK); ##-- nothing to do
  my $vars = pop(@STORABLE_STACK);
  ${"Storable::$_"} = $vars->{$_} foreach (keys %$vars);
  return $vars;
}


##==============================================================================
## Methods: Persistence
##==============================================================================

##======================================================================
## Methods: Persistence: Perl

## @keys = $class_or_obj->noSaveKeys()
##  + returns list of keys not to be saved for perl-mode I/O
##  + default just returns empty list
sub noSaveKeys { return qw(); }

## $saveRef = $obj->savePerlRef()
##  + return reference to be saved (hack)
##  + default implementation assumes $obj is HASH-ref
sub savePerlRef {
  my $obj = shift;
  my %noSave = map {($_=>undef)} $obj->noSaveKeys;
  return bless({
		map { ($_=>(ref($obj->{$_}) && can($obj->{$_},'savePerlRef') ? $obj->{$_}->savePerlRef : $obj->{$_})) }
		grep {
		  (!exists($noSave{$_})
		   && (!ref($obj->{$_})
		       || !isa($obj->{$_},'CODE')
		       || !isa($obj->{$_},'GLOB')
		       || (ref($obj) !~ /^DB_File\b/)
		       || !isa($obj->{$_},'IO::Handle')
		       || !isa($obj->{$_},'Gfsm::Automaton')
		       || !isa($obj->{$_},'Gfsm::Alphabet')
		       || !isa($obj->{$_},'Gfsm::Semiring')
		       || !isa($obj->{$_},'Gfsm::XL::Cascade')
		       || !isa($obj->{$_},'Gfsm::XL::Cascade::Lookup')
		      )
		  )}
		keys(%$obj)
	       }, ref($obj));
}

## $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref)
##  + default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses
sub loadPerlRef {
  my ($that,$ref) = @_;
  return $that if (!defined($ref) || $ref eq $that); ##-- literal load
  $that = ref($ref) if (UNIVERSAL::isa($ref,$that)); ##-- "virtual load": return subclass for superclass method
  my $obj = ref($that) ? $that : $that->new();
  $obj = bless(unifyClobber($obj,$ref,undef),ref($obj));
  if (UNIVERSAL::isa($that,'HASH') && UNIVERSAL::isa($obj,'HASH')) {
    %$that = %$obj; ##-- hack in case someone does "$obj->load()" and expects $obj to be destructively altered...
    return $that;
  } elsif (UNIVERSAL::isa($that,'ARRAY') && UNIVERSAL::isa($obj,'ARRAY')) {
    @$that = @$obj; ##-- ... analagous hack for array refs
    return $that;
  } elsif (UNIVERSAL::isa($that,'SCALAR') && UNIVERSAL::isa($obj,'SCALAR')) {
    $$that = $$obj; ##-- ... analagous hack for scalar refs
    return $that;
  }
  return $obj;
}

##----------------------------------------------------
## Methods: Persistence: Perl: File (delegate to string)

## $rc = $obj->savePerlFile($filename_or_fh, @args)
##  + calls "$obj->savePerlString(@args)"
sub savePerlFile {
  my ($obj,$file) = (shift,shift);
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  confess(ref($obj), "::savePerlFile(): open failed for '$file': $!")
    if (!$fh);
  $fh->print("## Perl code auto-generated by ", __PACKAGE__, "::savePerlFile()\n",
	     "## EDIT AT YOUR OWN RISK\n",
	     $obj->savePerlString(@_));
  $fh->close() if (!ref($file));
  return 1;
}

## $obj = $CLASS_OR_OBJ->loadPerlFile($filename_or_fh, %args)
##  + calls $CLASS_OR_OBJ->loadPerlString(var=>undef,src=>$filename_or_fh, %args)
sub loadPerlFile {
  my ($that,$file,%args) = @_;
  my $fh = ref($file) ? $file : IO::File->new("<$file");
  confess((ref($that)||$that), "::loadPerlFile(): open failed for '$file': $!") if (!$fh);
  local $/=undef;
  my $str = <$fh>;
  $fh->close() if (!ref($file));
  return $that->loadPerlString($str, var=>undef, src=>$file, %args);
}

##----------------------------------------------------
## Methods: Persistence: Perl: String (perl code)

## $str = $obj->savePerlString(%args)
##  + save $obj as perl code
##  + %args:
##      var => $perl_var_name
sub savePerlString {
  my ($obj,%args) = @_;
  my $var = $args{var} ? $args{var} : '$obj';
  my $dumper = (Data::Dumper->new([$obj],[$var])
		->Indent(1)
		->Purity(1)
		->Terse(0)
		->Sortkeys(1)
		->Freezer('freezePerlRef')
		->Toaster('toastPerlRef'));
  my $str    = join('', $dumper->Dump);

  ##-- un-freeze hack
  our (%PERL_FROZEN);
  foreach (values(%PERL_FROZEN)) {
    ${$_->[1]} = $_->[0];
  }
  %PERL_FROZEN = qw();

  return $str;
}

## $obj = $CLASS_OR_OBJ->loadPerlString($str,%args)
##  + %args:
##     var=>$perl_var_name, ##-- default='$index'                 ; local var: $VAR
##     src=>$src_name,      ##-- default=(substr($str,0,42).'...'); local var: $SRC
##     %more_obj_args,      ##-- literally inserted into $obj
##  + load from perl code string
sub loadPerlString {
  my ($that,$str,%args) = @_;
  my $var = $args{var} ? $args{var} : '$obj';
  my $src = (defined($args{src})
	     ? $args{src}
	     : (length($str) <= 42
		? $str
		: (substr($str,0,42).'...')));
  my $VAR = $var;
  my $SRC = (defined($args{src}) ? $args{src} : '/dev/null');
  my $TOP = $Lingua::TT::Unify::TOP;
  delete(@args{qw(var src)});

  my $loaded = eval("no strict; $str; $var");
  confess((ref($that)||$that), "::loadString(): eval() failed for '$src': ", $@ ? $@ : $!)
    if ($@ || !defined($loaded)); #|| $!

  return $that->loadPerlRef($loaded);
}

##----------------------------------------------------
## Methods: Persistence: Perl: freeze/toast

## undef = $obj->freezePerlRef()
##  + in-place freezer
sub freezePerlRef {
  our (%PERL_FROZEN);
  my $obj  = $_[0];
  my $ref  = bless($obj->savePerlRef(),ref($obj));
  my $okey = overload::StrVal($obj);
  my $rkey = overload::StrVal($ref);
  return $obj if ($okey eq $rkey);
  $PERL_FROZEN{$rkey} = [$obj,\$ref];
  $_[0] = $ref;
}

## undef = $obj->toastPerlRef()
##  + in-place toaster
sub toastPerlRef {
  $_[0] = $_[0]->loadPerlRef($_[0]);
}

##======================================================================
## Methods: Persistence: Binary

## @keys = $class_or_obj->noSaveBinKeys()
##  + returns list of keys not to be saved for binary mode I/O
##  + default just returns empty $obj->noSaveKeys()
sub noSaveBinKeys { return $_[0]->noSaveKeys(); }

## $binRef = $obj->saveBinRef()
##  + return reference to be saved in binary mode
##  + default implementation assumes $obj is HASH-ref
sub saveBinRef {
  my $obj = shift;
  my %noSave = map {($_=>undef)} $obj->noSaveBinKeys;
  return
    bless({
	   map { ($_=>(ref($obj->{$_}) && UNIVERSAL::can($obj->{$_},'saveBinRef') ? $obj->{$_}->saveBinRef() : $obj->{$_})) }
	   grep {
	     (!exists($noSave{$_})
	      && (!ref($obj->{$_})
		  || !UNIVERSAL::isa($obj->{$_},'CODE')
		  || !UNIVERSAL::isa($obj->{$_},'GLOB')
		  || !UNIVERSAL::isa($obj->{$_},'IO::Handle')
		  #|| !UNIVERSAL::isa($obj->{$_},'Gfsm::Automaton')
		  #|| !UNIVERSAL::isa($obj->{$_},'Gfsm::Alphabet')
		  #|| !UNIVERSAL::isa($obj->{$_},'Gfsm::Semiring')
		  #|| !UNIVERSAL::isa($obj->{$_},'Gfsm::XL::Cascade')
		  #|| !UNIVERSAL::isa($obj->{$_},'Gfsm::XL::Cascade::Lookup')
		 )
	     )}
	   keys(%$obj)
	  },
	  ref($obj));
}

## $loadedObj = $CLASS_OR_OBJ->loadBinRef($ref)
##  + default implementation just duplicates default loadPerlRef($ref)
sub loadBinRef {
  return Lingua::TT::Persistent::loadPerlRef(@_);
}

##----------------------------------------------------
## Methods: Persistence: Bin: File (delegate to FH)

## $rc = $obj->saveBinFile($filename_or_fh, %args)
##  + save $obj as binary data to a file or filehandle
##  + calls $obj->saveBinFh($fh,%args)
sub saveBinFile {
  my ($obj,$file,%args) = @_;
  my $fh = ref($file) ? $file : IO::File->new(">$file");
  confess(ref($obj)."::saveBinFile(): open failed for '$file': $!") if (!$fh);
  my $rc = $obj->saveBinFh($fh,%args,dst=>$file);
  $fh->close() if (!ref($file));
  return $rc;
}

## $obj = $CLASS_OR_OBJ->loadBinFile($filename_or_fh, %args)
##  + load $obj as binary data from a file or filehandle
##  + calls $obj->loadBinFh($fh,%args)
sub loadBinFile {
  my ($that,$file,%args) = @_;
  my $fh = ref($file) ? $file : IO::File->new("<$file");
  confess((ref($that)||$that)."::loadBinFile(): open failed for '$file': $!") if (!$fh);
  my $rc = $that->loadBinFh($fh,%args,src=>$file);
  $fh->close() if (!ref($file));
  return $rc;
}

##----------------------------------------------------
## Methods: Persistence: Bin: String (delegate to FH)

## $str = $obj->saveBinString(%args)
##  + save $obj as binary data using Storable module
##  + calls $obj->saveBinFh($fh,%args)
sub saveBinString {
  my ($obj,%args) = @_;
  my $str = '';
  my $fh  = IO::Handle->new();
  CORE::open($fh,'>',\$str)
      or confess(ref($obj)."::saveBinString(): could not open() filehandle for string ref");
  my $rc = $obj->saveBinFh($fh);
  $fh->close();
  return $rc ? $str : undef;
}

## $obj = $CLASS_OR_OBJ->loadBinString( $str, %args)
## $obj = $CLASS_OR_OBJ->loadBinString(\$str, %args)
##  + load $obj from Storable binary data string
##  + calls $obj->loadBinFh($fh,%args)
##  + %args:
##     src=>$src_name,      ##-- default=(substr($str,0,42).'...')
sub loadBinString {
  my ($that,$str,%args) = @_;
  my $src = (defined($args{src})
	     ? $args{src}
	     : (length($str) <= 42
		? $str
		: (substr($str,0,42).'...')));

  my $fh = IO::Handle->new();
  CORE::open($fh,'<',(ref($str) ? $str : \$str))
      or confess((ref($that)||$that)."::loadBinString(): could not open() filehandle for string ref");
  my $rc = $that->loadBinFh($fh,src=>$src,%args);
  $fh->close;
  return $rc;
}

##----------------------------------------------------
## Methods: Persistence: Bin: FH (guts)

## $obj_or_undef = $obj->saveBinFh($fh,%args)
##  + save $obj to binary Storable data handle
##  + calls $obj->saveBinRef()
##  + %args:
##     netorder => $bool,    ##-- if true (default), save in network order
sub saveBinFh {
  my ($obj,$fh,%args) = @_;
  my $ref = $obj->saveBinRef();
  if ($args{netorder} || !exists($args{netorder})) {
    return Storable::nstore_fd($ref,$fh) ? $obj : undef;
  }
  return Storable::store_fd($ref,$fh) ? $obj : undef;
}

## $obj = $CLASS_OR_OBJ->loadBinFh($fh, %args)
##  + load $obj from Storable binary data handle
##  + calls $obj->loadBinFh($fh,%args)
##  + %args:
##     src=>$src_name,      ##-- default=(substr($str,0,42).'...')
sub loadBinFh {
  my ($that,$fh,%args) = @_;
  my $loaded = Storable::retrieve_fd($fh);
  return $that->loadBinRef($loaded);
}

##======================================================================
## Methods: Persistence: Native

##----------------------------------------------------
## Methods: Persistence: Native: File (delegate to FH)

## $rc = $obj->saveNativeFile($filename_or_fh, %args)
##  + save $obj as native data to a file or filehandle
##  + calls $obj->saveNativeFh($fh,%args)
sub saveNativeFile {
  my ($obj,$file,%args) = @_;
  my $fh = ref($file) ? $file : Lingua::TT::IO->open(">",$file,%args)->{fh};
  confess(ref($obj)."::saveNativeFile(): open failed for '$file': $!") if (!$fh);
  my $rc = $obj->saveNativeFh($fh,%args,dst=>$file);
  $fh->close() if (!ref($file));
  return $rc;
}

## $obj = $CLASS_OR_OBJ->loadNativeFile($filename_or_fh, %args)
##  + load $obj as native data from a file or filehandle
##  + calls $obj->loadNativeFh($fh,%args)
sub loadNativeFile {
  my ($that,$file,%args) = @_;
  my $fh = ref($file) ? $file : Lingua::TT::IO->open("<",$file,%args)->{fh};
  confess((ref($that)||$that)."::loadNativeFile(): open failed for '$file': $!") if (!$fh);
  my $rc = $that->loadNativeFh($fh,%args,src=>$file);
  $fh->close() if (!ref($file));
  return $rc;
}

##----------------------------------------------------
## Methods: Persistence: Native: String (delegate to FH)

## $str = $obj->saveNativeString(%args)
##  + save $obj as native data using object-local method $that->saveNativeFh()
##  + calls $obj->saveBinFh($fh,%args)
sub saveNativeString {
  my ($obj,%args) = @_;
  my $str = '';
  my $fh  = Lingua::TT::IO->toString(\$str,%args)->{fh};
  my $rc = $obj->saveNativeFh($fh);
  $fh->close();
  return $rc ? $str : undef;
}

## $obj = $CLASS_OR_OBJ->loadNativeString( $str, %args)
## $obj = $CLASS_OR_OBJ->loadNativeString(\$str, %args)
##  + load $obj from native data string
##  + calls $obj->loadNativeFh($fh,%args)
##  + %args:
##     src=>$src_name,      ##-- default=(substr($str,0,42).'...')
sub loadNativeString {
  my ($that,$str,%args) = @_;
  my $src = (defined($args{src})
	     ? $args{src}
	     : (length($str) <= 42
		? $str
		: (substr($str,0,42).'...')));
  my $fh  = Lingua::TT::IO->fromString(\$str,%args)->{fh};
  my $rc = $that->loadNativeFh($fh,src=>$src,%args);
  $fh->close;
  return $rc;
}

##----------------------------------------------------
## Methods: Persistence: Native: FH (guts)
##  + should be overridden by descendant classes supporting native I/O mode

## $obj_or_undef = $obj->saveNativeFh($fh,%args)
##  + save $obj to native data handle
##  + %args: ?
sub saveNativeFh {
  my ($obj,$fh,%args) = @_;
  confess(ref($obj)."::saveNativeFh(): abstract method called!");
}

## $obj = $CLASS_OR_OBJ->loadBinFh($fh, %args)
##  + load $obj from native data handle
##  + %args: ?
sub loadNativeFh {
  my ($that,$fh,%args) = @_;
  confess((ref($that)||$that)."::loadNativeFh(): abstract method called!");
}

##======================================================================
## Methods: Persistence: Generic

##----------------------------------------------------
## Methods: Persistence: Generic: utils

## $mode = $CLASS_OR_OBJ->guessFileMode($filename)
sub guessFileMode {
  my ($that,$filename) = @_;
  return 'bin' if ($filename =~ /\.(?:sto|bin)$/i);
  return 'perl' if ($filename =~ /\.(?:perl|pl|plm|pm|p)$/i);
  return 'native' if ($that->can('saveNativeFh') ne __PACKAGE__->can('saveNativeFh'));
  return 'perl';
}

## $rc = $CLASS_OR_OBJ->_io_generic(%args)
##  + generic I/O wrapper
##  + %args:
##     which => $which, ##-- one of: 'load' or 'save' (default)
##     mode  => $mode,  ##-- one of: 'bin' or 'perl' (default: guessFileMode($file))
##     type  => $type,  ##-- one of: 'file', 'fh', or 'string' (default)
##     file  => $file,  ##-- any filename, used to guess mode
##     arg0  => $arg0,  ##-- first arg to pass to the underlying I/O method (default=none)
sub _io_generic {
  my ($that,%args) = @_;
  $args{mode} = $that->guessFileMode($args{file}) if ($args{file} && !$args{mode});
  $args{which} = 'save' if (!$args{which});
  $args{type} = 'string' if (!$args{type});
  my $subname = $args{which}.ucfirst(lc($args{mode})).ucfirst(lc($args{type}));
  my $sub = $that->can($subname)
    or confess((ref($that)||$that)."::_io_generic(): no method for '$subname'");
  return $sub->($that, (exists($args{arg0}) ? $args{arg0} : qw()), %args);
}

##----------------------------------------------------
## Methods: Persistence: Generic: save

## $obj_or_undef = $CLASS_OR_OBJ->save(%args)
##  + %args: see _io_generic()
sub save {
  my ($that,%args) = @_;
  return $that->_io_generic(%args,which=>'save');
}

## $obj_or_undef = $CLASS_OR_OBJ->saveFile($filename_or_fh,%args)
##  + %args: see _io_generic()
sub saveFile {
  my ($that,$file,%args) = @_;
  return $that->_io_generic(file=>$file,%args,which=>'save',type=>'file',arg0=>$file);
}
BEGIN { *saveFh = \&saveFile; }

## $obj_or_undef = $CLASS_OR_OBJ->saveString(%args)
##  + %args: see _io_generic()
sub saveString {
  my ($that,%args) = @_;
  return $that->_io_generic(%args,which=>'save',type=>'string');
}

##----------------------------------------------------
## Methods: Persistence: Generic: load

## $obj_or_undef = $CLASS_OR_OBJ->load(%args)
##  + %args: see _io_generic()
sub load {
  my ($that,%args) = @_;
  return $that->_io_generic(%args,which=>'load');
}

## $obj_or_undef = $CLASS_OR_OBJ->loadFile($filename_or_fh,%args)
##  + %args: see _io_generic()
sub loadFile {
  my ($that,$file,%args) = @_;
  return $that->_io_generic(file=>$file,%args,which=>'load',type=>'file',arg0=>$file);
}
BEGIN { *loadFh = \&loadFile; }

## $obj_or_undef = $CLASS_OR_OBJ->loadString($string,%args)
##  + %args: see _io_generic()
sub loadString {
  my ($that,$str,%args) = @_;
  return $that->_io_generic(%args,which=>'load',type=>'string');
}


1; ##-- be happy

__END__
##========================================================================
## POD DOCUMENTATION, auto-generated by podextract.perl

##========================================================================
## NAME
=pod

=head1 NAME

Lingua::TT::Persistent - abstract class for persistent & configurable objects

=cut

##========================================================================
## SYNOPSIS
=pod

=head1 SYNOPSIS

 use Lingua::TT::Persistent;
 
 ##========================================================================
 ## Constructors etc.
 
 $obj = $obj->clone();
 
 ##========================================================================
 ## Methods: Persistence: Perl
 
 @keys = $class_or_obj->noSaveKeys();
 $saveRef = $obj->savePerlRef();
 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);
 
 $rc = $obj->savePerlFile($filename_or_fh, @args);
 $obj = $CLASS_OR_OBJ->loadPerlFile($filename_or_fh, %args);
 
 $str = $obj->savePerlString(%args);
 $obj = $CLASS_OR_OBJ->loadPerlString($str,%args);
 
 ##========================================================================
 ## Methods: Persistence: Binary
 
 @keys = $class_or_obj->noSaveBinKeys();
 $saveRef = $obj->saveBinRef();
 $loadedObj = $CLASS_OR_OBJ->loadBinRef($ref);
 
 $rc = $obj->saveBinFile($filename_or_fh, @args);
 $obj = $CLASS_OR_OBJ->loadBinFile($filename_or_fh, %args);
 
 $str = $obj->saveBinString(%args);
 $obj = $CLASS_OR_OBJ->loadBinString($str,%args);
 
 ##========================================================================
 ## Methods: Persistence: Generic
 
 $mode = $CLASS_OR_OBJ->guessFileMode($filename);
 
 $rc = $obj->saveFile($filename_or_fh, %args);
 $obj = $CLASS_OR_OBJ->loadFile($filename_or_fh, %args);
 
 $str = $obj->saveString(%args);
 $obj = $CLASS_OR_OBJ->loadString($str,%args);

=cut

##========================================================================
## DESCRIPTION
=pod

=head1 DESCRIPTION

=cut

##----------------------------------------------------------------
## DESCRIPTION: Lingua::TT::Persistent: Constructors etc.
=pod

=head2 Constructors etc.

=over 4

=item clone

 $obj = $obj->clone();

Deep clone using Storable::dclone().

=back

=cut

##----------------------------------------------------------------
## DESCRIPTION: Lingua::TT::Persistent: Methods: Persistence: Perl
=pod

=head2 Methods: Persistence: Perl

=over 4

=item noSaveKeys

 @keys = $class_or_obj->noSaveKeys();

Should returns list of object keys not to be saved on L</savePerlRef>()
(e.g. CODE-refs and anything else which L<Data::Dumper|Data::Dumper>
and/or L<Storable::Storable> can't handle).

Default implementation just returns an empty list.

=item savePerlRef

 $saveRef = $obj->savePerlRef();

Return a reference to be saved.
Default implementation assumes $obj is HASH-ref

=item loadPerlRef

 $loadedObj = $CLASS_OR_OBJ->loadPerlRef($ref);

Returns an object-reference constructed from the saved representation $ref,
which should be a reference as returned by L</savePerlRef>.
Default implementation just clobbers $CLASS_OR_OBJ with $ref and blesses it.

=item savePerlFile

 $rc = $obj->savePerlFile($filename_or_fh, @args);

Save $obj as perl code to $filename_or_fh.
Calls L<$obj-E<gt>savePerlString(@args)|/savePerlString>

=item loadPerlFile

 $obj = $CLASS_OR_OBJ->loadPerlFile($filename_or_fh, %args);

Load a (new) object from perl code in $filename_or_fh.
Calls L<$CLASS_OR_OBJ-E<gt>loadPerlString(var=E<gt>undef,src=E<gt>$filename_or_fh, %args)|/loadPerlString>.

=item savePerlString

 $str = $obj->savePerlString(%args);

Save $obj as perl code, returns perl code string.

Known %args:

 var => $perl_var_name,  ##-- default=$obj

=item loadPerlString

 $obj = $CLASS_OR_OBJ->loadPerlString($str,%args);

Load an object from a perl code string $str.  Returns new object.

Known %args:

 var=>$perl_var_name, ##-- default='$index'
 src=>$src_name,      ##-- default=(substr($str,0,42).'...')
 %more_obj_args,      ##-- literally inserted into $obj

=back

=cut


##----------------------------------------------------------------
## DESCRIPTION: Lingua::TT::Persistent: Methods: Persistence: Binary
=pod

=head2 Methods: Persistence: Binary

=over 4

=item noSaveBinKeys

 @keys = $class_or_obj->noSaveKeys();

Should returns list of object keys not to be saved on L</saveBinRef>()
(e.g. CODE-refs and anything else which
L<Storable|Storable> can't handle).

Default implementation just returns an empty list.

=item saveBinRef

 $saveRef = $obj->saveBinRef();

Return a reference to be saved in binary mode.
Default implementation assumes $obj is HASH-ref

=item loadBinRef

 $loadedObj = $CLASS_OR_OBJ->loadBinRef($ref);

Just a wrapper for the local L</loadPerlRef> method,
used for binary loading (in case sub-classes override loadPerlRef()).

=item saveBinFile

 $rc = $obj->saveBinFile($filename_or_fh, %args);

Save binary $obj to $filename_or_fh using L<Storable|Storable> module
Calls L<$obj-E<gt>saveBinFh(%args)|/saveBinFh>

=item loadBinFile

 $obj = $CLASS_OR_OBJ->loadBinFile($filename_or_fh, %args);

Load a (new) object from binary file or handle $filename_or_fh.
Calls L<$CLASS_OR_OBJ-E<gt>loadBinFh($fh,%args)|/loadBinFh>.

=item saveBinString

 $str = $obj->saveBinString(%args);

Returns binary byte-string representing $obj.
Calls L<$CLASS_OR_OBJ-E<gt>saveBinFh($fh,%args)|/loadBinFh>.

=item loadBinString

 $obj = $CLASS_OR_OBJ->loadBinString($str,%args);

Load an object from a binary string $str.  Returns new object.

=item saveBinFh

 $str = $obj->saveBinFh($fh,%args);

Save binary format $obj to filehandle $fh.

Known %args:

 netorder => $bool,  ##-- if true (default), save data in "network" order where possible

=item loadBinFh

 $obj = $CLASS_OR_OBJ->loadBinFh($fh,%args);

Load an object from a binary filehandle $fh.  Returns new object.

=back

=cut


##----------------------------------------------------------------
## DESCRIPTION: Lingua::TT::Persistent: Methods: Persistence: Generic
=pod

=head2 Methods: Persistence: Generic

The I/O methods documented in this section recognize the following keyword %args:

 mode  => $mode,  ##-- one of: 'bin' or 'perl' (default: guessFileMode($file))
 file  => $file,  ##-- any filename, used to guess mode

=over 4

=item guessFileMode

 $mode = $CLASS_OR_OBJ->guessFileMode($filename)

Guess I/O mode ('bin' or 'perl') from a filename.

=item saveFile

 $obj_or_undef = $obj->saveFile($filename_or_fh,%args)

Save to a generic filename or handle $filename_or_fh.

=item loadFile

 $loaded_obj = $CLASS_OR_OBJ->loadFile($filename_or_fh,%args)

Load from a generic filename or handle $filename_or_fh.

=item saveString

 $str = $obj->saveString(%args)

Save to a generic string.

=item loadString

 $loaded_obj = $CLASS_OR_OBJ->loadString($str,%args)

Load from a generic string $str.

=back

=cut

##========================================================================
## END POD DOCUMENTATION, auto-generated by podextract.perl

##======================================================================
## Footer
##======================================================================
=pod

=head1 AUTHOR

Bryan Jurish E<lt>jurish@bbaw.deE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2009 by Bryan Jurish

This package is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.4 or,
at your option, any later version of Perl 5 you may have available.

=cut
