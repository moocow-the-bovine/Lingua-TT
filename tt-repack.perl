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
our $packfmt   = 'w';
our $unpackfmt = 'N';

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'output|o=s' => \$outfile,
	   'from|unpackfmt|unpack|u=s' => \$unpackfmt,
	   'to|packfmt|pack|p=s' => \$packfmt,
	   #'delim|d:s' => \$delim,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
#pod2usage({-exitval=>0,-verbose=>0,-msg=>'No ENUM specified!'}) if (!@ARGV);
#$enumfile = shift;

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

##-- guts
our $outfh = IO::File->new(">$outfile")
  or die("$prog: open failed for output file '$outfile': $!");
binmode($outfh);

push(@ARGV,'-') if (!@ARGV);
foreach $infile (@ARGV) {
  my $infh = IO::File->new("<$infile")
    or die("$prog: open failed for input file '$infile': $!");

  ##-- fast mode (always)
  local $/=undef;
  $buf = <$infh>;
  $outfh->print(pack("${packfmt}*",unpack("${unpackfmt}*",$buf)));
  $infh->close();
}
$outfh->close();


__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-repack.perl - recode packed tt files

=head1 SYNOPSIS

 tt-repack.perl [OPTIONS] [PACKED_FILE(s)]

 General Options:
   -help
   -version
   -verbose LEVEL

 Other Options:
   -unpack TEMPLATE       ##-- input pack template (default='w')
   -pack   TEMPLATE       ##-- output pack template (default='N')
   -output FILE           ##-- output file (default=STDOUT)

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
