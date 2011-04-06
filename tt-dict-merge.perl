#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::Dict;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION  = "0.01";
our $encoding = undef;
our $outfile  = '-';
our $append   = 0;

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,

	   ##-- I/O
	   'output|o=s' => \$outfile,
	   'encoding|e=s' => \$encoding,
	   'append|a!' => \$append,
	   'clobber|c!' => sub { $append=!$_[1]; },
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
#pod2usage({-exitval=>0,-verbose=>0,-msg=>'No dictionary file specified!'}) if (!@ARGV);

##----------------------------------------------------------------------
## Subs

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------

##-- i/o
our $ttout = Lingua::TT::IO->toFile($outfile,encoding=>$encoding)
  or die("$0: open failed for '$outfile': $!");
our $outfh = $ttout->{fh};

##-- create dict
my ($dict);

##-- munge arguments
push(@ARGV,'-') if (!@ARGV);
foreach $dictfile (@ARGV) {
  my $d2 = Lingua::TT::Dict->loadFile($dictfile,encoding=>$encoding)
    or die("$0: load failed for file '$dictfile': $!");

  if (!defined($dict)) {
    $dict = $d2;
  } else {
    $dict->merge($d2, append=>$append);
  }
}

$dict = Lingua::TT::Dict->new if (!$dict);

##-- dump
$dict->saveFile($outfile,encoding=>$encoding);

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-dict-merge.perl - merge text-keyed TT dictionary files

=head1 SYNOPSIS

 tt-dict-merge.perl [OPTIONS] DICT_FILE(s)...

 General Options:
   -help

 I/O Options:
  -output FILE         ##-- default: STDOUT
  -encoding ENCODING   ##-- default: UTF-8
  -append  , -clobber  ##-- append or clobber old analyses for multiple entries? (default=-clobber)

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
