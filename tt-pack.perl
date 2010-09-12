#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::Enum;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);


##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION = "0.01";

##-- program vars
our $prog     = basename($0);
our $verbose      = 1;

our $outfile      = '-';
our $encoding     = undef;
our $enumfile     = undef,
our $enum_ids     = 0;

our $packfmt = 'N';
our $want_cmts = 1;
our $want_eos  = 1;
our $badid = 0; ##-- "bad" id (default=0)
our $fast = 0; ##-- fast mode? (doesn't help much here)

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'buffer|buf|fast!' => \$fast,
	   'slow|paranoid' => sub { $fast=!$_[1]; },
	   'output|o=s' => \$outfile,
	   'encoding|e=s' => \$encoding,
	   'enum-ids|ids|ei!' => \$enum_ids,

	   'packfmt|pack|p=s' => \$packfmt,
	   'comments|cmts|c!' => \$want_cmts,
	   'badid|bad|b=s' => \$badid,
	   'eos|s!' => \$want_eos,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>0,-msg=>'No ENUM specified!'}) if (!@ARGV);
$enumfile = shift;

if ($version || $verbose >= 2) {
  print STDERR "$prog version $VERSION by Bryan Jurish\n";
  exit 0 if ($version);
}

##----------------------------------------------------------------------
## Subs: messages
##----------------------------------------------------------------------

# undef = vmsg($level,@msg)
#  + print @msg to STDERR if $verbose >= $level
sub vmsg {
  my $level = shift;
  print STDERR (@_) if ($verbose >= $level);
}

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------

##-- open enum
our $enum = Lingua::TT::Enum->new();
our %enum_io_opts = (encoding=>$encoding, noids=>(!$enum_ids));
$enum = $enum->loadNativeFile($enumfile,%enum_io_opts)
    or die("$prog: coult not load enum file '$enumfile': $!");
our $sym2id = $enum->{sym2id};

##-- guts
our $outfh = IO::File->new(">$outfile")
  or die("$prog: open failed for output file '$outfile': $!");
$outfh->binmode();
our ($ttin);

foreach $infile (@ARGV) {
  $ttin = Lingua::TT::IO->fromFile($infile,encoding=>$encoding)
    or die("$0: open failed for input file '$infile': $!");
  my $infh = $ttin->{fh};

  if ($fast) {
    ##-- fast mode (not really faster)
    $outfh->print(pack("${packfmt}*",
		       @$sym2id{
				map {
				  chomp;
				  ((/^\s*%%/ && !$want_cmts) || ($_ eq '' && !$want_eos)
				   ? qw()
				   : $_)
				} <$infh>
			       }));
  } else {
    ##-- paranoid mode
    while (defined($_=<$infh>)) {
      chomp;
      next if ((/^\s*%%/ && !$want_cmts) || ($_ eq '' && !$want_eos));
      if (!defined($id = $sym2id->{$_})) {
	warn("$prog: WARNING: no id for input '$_'; using -badid=$badid");
	$id=$badid;
      }
      #$packed = pack($packfmt,$id);
      #substr($packed,length($packed)-1) |= $hibit if ($packfmt eq 'w');
      #$outfh->print($packed,$delim);
      ##--
      $outfh->print(pack($packfmt,$id));
    }
  }
  $infh->close();
}
$outfh->close();


__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-pack.perl - encode tt files using pre-compiled enum

=head1 SYNOPSIS

 tt-pack.perl [OPTIONS] ENUM [TTFILE(s)]

 General Options:
   -help
   -version
   -verbose LEVEL

 Other Options:
   -fast                ##-- run in fast buffer mode with no error checks
   -paranoid            ##-- run in slow "paranoid" mode (default)
   -ids  , -noids       ##-- do/don't expect ids in ENUM (default=don't)
   -cmts , -nocmts      ##-- do/don't pack comments (requires comments in ENUM; default=don't)
   -eos  , -noeos       ##-- do/don't pack EOS (requires empty string in ENUM; default=do)
   -pack TEMPLATE       ##-- pack template for output ids (default='N')
   -encoding ENC        ##-- input encoding (default=raw)
   -output FILE         ##-- output file (default=STDOUT)

=cut

###############################################################
## OPTIONS
###############################################################
=pod

=head1 OPTIONS

=cut

###############################################################
# General Options
###############################################################
=pod

=head2 General Options

=over 4

=item -help

Display a brief help message and exit.

=item -version

Display version information and exit.

=item -verbose LEVEL

Set verbosity level to LEVEL.  Default=1.

=back

=cut


###############################################################
# Other Options
###############################################################
=pod

=head2 Other Options

=over 4

=item -someoptions ARG

Example option.

=back

=cut


###############################################################
# Bugs and Limitations
###############################################################
=pod

=head1 BUGS AND LIMITATIONS

Probably many.

=cut


###############################################################
# Footer
###############################################################
=pod

=head1 ACKNOWLEDGEMENTS

Perl by Larry Wall.

=head1 AUTHOR

Bryan Jurish E<lt>jurish@uni-potsdam.deE<gt>

=head1 SEE ALSO

perl(1).

=cut
