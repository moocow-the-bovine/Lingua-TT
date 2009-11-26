#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::Diff;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);


##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION = "0.01";

##-- program vars
our $progname     = basename($0);
our $verbose      = 1;

our $outfile      = '-';
our %diffargs     = qw();
our %appargs      = ( prefer=>1, fix=>1 );
our %ioargs       = ( encoding=>'UTF-8');

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   'man|m'  => \$man,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'prefer|pref|which|p|w=i' => \$appargs{prefer},
	   '1' => sub { $appargs{prefer}=1; },
	   '2' => sub { $appargs{prefer}=2; },
	   'fixes|fix|f!' => \$appargs{fix},
	   'encoding|e=s' => \$ioargs{encoding},
	   'output|o=s' => \$outfile,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>1}) if ($man);
#pod2usage({-exitval=>0,-verbose=>1,-msg=>'Not enough arguments specified!'}) if (@ARGV < 2);

if ($version || $verbose >= 2) {
  print STDERR "$progname version $VERSION by Bryan Jurish\n";
  exit 0 if ($version);
}

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
push(@ARGV,'-') if (!@ARGV);

our $diff = Lingua::TT::Diff->new(%diffargs);
our $dfile = shift(@ARGV);
$diff->loadTextFile($dfile)
  or die("$0: load failed from '$dfile': $!");

our $seq = $diff->apply(%appargs)
  or die("$0: apply() failed: $!");

##-- dump
our $ttio = Lingua::TT::IO->toFile($outfile,%ioargs)
  or die("$0: open failed for '$outfile': $!");
$ttio->putLines($seq)
  or die("$0: ", ref($ttio)."::putLines() failed: $!");
$ttio->close();

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-diff-apply.perl - apply a Lingua::TT::Diff

=head1 SYNOPSIS

 tt-diff-apply.perl OPTIONS [TT_DIFF_FILE]

 General Options:
   -help
   -version
   -verbose LEVEL

 Other Options:
   -prefer=WHICH        ##-- prefer which file (1 or 2; default=1)
   -1                   ##-- alias for -prefer=1
   -2                   ##-- alias for -prefer=2
   -fix , -nofix        ##-- diff "fixes" do/don't override WHICH (default=-fix)
   -encoding ENCODING   ##-- set output encoding (default=UTF-8)
   -output FILE         ##-- output file (default: STDOUT)

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

Bryan Jurish E<lt>moocow@ling.uni-potsdam.deE<gt>

=head1 SEE ALSO

perl(1).

=cut
