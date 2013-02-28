#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::Diff;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

##----------------------------------------------------------------------
## Globals

##-- verbosity levels
our $vl_silent = 0;
our $vl_error = 1;
our $vl_warn = 2;
our $vl_info = 3;
our $vl_trace = 4;

our $prog         = basename($0);
our $verbose      = $vl_info;
our $VERSION	  = 0.01;

our $outfile      = '-';
our %ioargs       = (encoding=>'utf8');
our %saveargs     = (shared=>1, context=>undef, syntax=>1);
our %diffargs     = (auxEOS=>0, auxComments=>1, diffopts=>''
		    );

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- misc
	   'output|o=s' => \$outfile,
	   'encoding|e=s' => \$ioargs{encoding},
	   'keep|K!'  => \$diffargs{keeptmp},
	   'header|syntax|S!' => \$saveargs{syntax},
	   'diff-options|D' => \$diffargs{diffopts},
	   'minimal|d' => sub { $diffargs{diffopts} .= ' -d'; },
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>0,-msg=>'Not enough arguments specified!'}) if (@ARGV < 2);

if ($version || $verbose >= 2) {
  print STDERR "$prog version $VERSION by Bryan Jurish\n";
  exit 0 if ($version);
}


if ($diffargs{keeptmp}) {
  $diffargs{tmpfile1} //= 'tmp_txt.t0';
  $diffargs{tmpfile2} //= 'tmp_tt.t0';
}

##----------------------------------------------------------------------
## messages
sub vmsg {
  my $level = shift;
  print STDERR @_ if ($verbose >= $level);
}
sub vmsg1 {
  my $level = shift;
  vmsg($level, "$prog: ", @_, "\n");
}

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
our ($txtfile,$ttfile) = @ARGV;

##-- get raw text buffer
vmsg1($vl_info, "buffering text data from $txtfile ...");
my ($txtbuf);
{
  local $/=undef;
  open(TXT,"<:encoding($ioargs{encoding})",$txtfile)
    or die("$prog: open failed for $txtfile: $!");
  $txtbuf=<TXT>;
  close(TXT);
}

##-- get raw tt data
vmsg1($vl_info, "buffering TT data from $ttfile ...");
my $ttio  = Lingua::TT::IO->fromFile($ttfile,%ioargs)
  or die("$0: could not open Lingua::TT::IO from $ttfile: $!");
my $ttlines = $ttio->getLines();

##-- split to characters
vmsg1($vl_info, "extracting text characters ...");
my @txtchars = map {$_ =~ /\R/ ? '' : $_} split(//,$txtbuf);

vmsg1($vl_info, "extracting token characters ...");
my ($l,$w,$c);
my @ttchars  = (
		map {
		  ($w = $ttlines->[$_]) =~ s/\t.*$//;
		  $l = "\t$_";
		  ($w =~ /^\%\%/ || $w =~ /^$/
		   ? qw()
		   : (map { $_ .= $l; $l=''; "$_\n" } split(//,$w)))
		} (0..$#$ttlines)
	       );


##-- run tt-diff comparison
vmsg1($vl_info, "comparing ...");
our $diff = Lingua::TT::Diff->new(%diffargs);
$diff->compare(\@txtchars,\@ttchars)
  or die("$0: diff->compare() failed: $!");
@$diff{qw(file1 file2)} = ("$txtfile (text)", "$ttfile (tokens)");

vmsg1($vl_info, "dumping diff to $outfile ...");
$diff->saveTextFile($outfile, %saveargs)
  or die("$0: diff->saveTextFile() failed for '$outfile': $!");

vmsg1($vl_info, "done.\n");

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-txt-align.perl - align raw-text and TT-format files

=head1 SYNOPSIS

 tt-txt-align.perl [OPTIONS] TEXT_FILE TT_FILE

 General Options:
   -help
   -version
   -verbose LEVEL

 Other Options:
   -output FILE         ##-- output file (default: STDOUT)
   -encoding ENC        ##-- input encoding (default: utf8) [output is always utf8]
   -D DIFF_OPTIONS      ##-- pass DIFF_OPTIONS to GNU diff
   -minimal             ##-- alias for -D='-d'
   -header , -noheader  ##-- do/don't output header comments (default=do)
   -keep   , -nokeep    ##-- do/don't keep temp files (default=don't)

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

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 SEE ALSO

perl(1).

=cut
