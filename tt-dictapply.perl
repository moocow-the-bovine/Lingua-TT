#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION = "0.01";
our $encoding = "UTF-8";
our $outfile = '-';

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   #'man|m'  => \$man,
	   #'version|V' => \$version,
	   #'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'output|o=s' => \$outfile,
	   'encoding|e=s' => \$encoding,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>0,-msg=>'No dictionary file specified!'}) if (!@ARGV);

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------

##-- i/o
our $ttout = Lingua::TT::IO->toFile($outfile,encoding=>$encoding)
  or die("$0: open failed for '$outfile': $!");

##-- read type dict
my $dictfile = shift(@ARGV);
our $ttin = Lingua::TT::IO->fromFile($dictfile,encoding=>$encoding)
  or die("$0: open failed for '$dictfile': $!");
my $dictdoc = $ttin->getDocument;
$ttin->close;
our %dict = map {($_->[0]=>$_)} grep {$_->isVanilla} map {@$_} @$dictdoc;

##-- process token files
my ($tok);
foreach $infile (@ARGV ? @ARGV : '-') {
  $ttin = Lingua::TT::IO->fromFile($infile,encoding=>$encoding)
    or die("$0: open failed for '$infile': $!");

  while (defined($tok=$ttin->getToken)) {
    next if (!$tok->isVanilla);
    if (defined($dtok=$dict{$tok->[0]})) {
      push(@$tok,@$dtok[1..$#$dtok]);
    }
    #else { warn("$0: no dictionary entry for input token text '$tok->[0]'"); }
  }
  continue {
    $ttout->putToken($tok);
  }
}

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-dictapply.perl - apply text-keyed dictionary analyses to TT file(s)

=head1 SYNOPSIS

 tt-dictapply.perl OPTIONS DICT_FILE [TT_FILE(s)]

 General Options:
   -help
   #-version
   #-verbose LEVEL

 I/O Options:
   -output FILE         ##-- default: STDOUT
   -encoding ENCODING   ##-- default: UTF-8

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
