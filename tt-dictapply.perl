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
our $include_empty = 0;

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,

	   ##-- I/O
	   'output|o=s' => \$outfile,
	   'encoding|e=s' => \$encoding,
	   'include-empty-analyses|allow-empty|empty!' => \$include_empty,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>0,-msg=>'No dictionary file specified!'}) if (!@ARGV);

##----------------------------------------------------------------------
## Subs

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------

##-- i/o
our $ttout = Lingua::TT::IO->toFile($outfile,encoding=>$encoding)
  or die("$0: open failed for '$outfile': $!");
our $outfh = $ttout->{fh};

##-- read type dict
my $dictfile = shift(@ARGV);
my $dict = Lingua::TT::Dict->loadFile($dictfile,encoding=>$encoding)
  or die("$0: load failed for dict file '$dictfile': $!");
my $dh = $dict->{dict};

##-- process token files
foreach $infile (@ARGV ? @ARGV : '-') {
  $ttin = Lingua::TT::IO->fromFile($infile,encoding=>$encoding)
    or die("$0: open failed for '$infile': $!");
  $infh = $ttin->{fh};

  while (defined($_=<$infh>)) {
    next if (/^%%/ || /^$/);
    chomp;
    ($text,$a_in) = split(/\t/,$_,2);
    $a_dict = $dh->{$text};
    $_ = join("\t", $text, (defined($a_in) ? $a_in : qw()), (defined($a_dict) && ($include_empty || $a_dict ne '') ? $a_dict : qw()))."\n";
  }
  continue {
    $outfh->print($_);
  }
  $ttin->close;
}


__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-dictapply.perl - apply text-keyed dictionary analyses to TT file(s)

=head1 SYNOPSIS

 tt-dictapply.perl [OPTIONS] DICT_FILE [TT_FILE(s)]

 General Options:
   -help

 I/O Options:
  -output FILE         ##-- default: STDOUT
  -encoding ENCODING   ##-- default: UTF-8
  -empty , -noempty     ##-- do/don't output empty analyses (default=don't)

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
