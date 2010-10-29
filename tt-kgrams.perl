#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::Unigrams;

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

our $globargs = 1; ##-- glob @ARGV?
our $listargs = 0; ##-- args are file-lists?
our $eos       = '';
our $k = 2;

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'glob|g!' => \$globargs,
	   'list|l!' => \$listargs,
	   'k=i' => \$k,
	   'output|o=s' => \$outfile,
	   'encoding|e=s' => \$encoding,
	   'eos|s:s' => \$eos,
	   'no-eos|noeos|S' => sub { undef $eos; },
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);

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
## subs: guts

sub processTTFile {
  my ($ttfile,$outfh) = @_;
  my $ttin = Lingua::TT::IO->fromFile($ttfile,encoding=>$encoding)
    or die("$0: open failed for input file '$ttfile': $!");
  my $infh = $ttin->{fh};

  my @kg = (map {$eos} (1..$k));
  my $i0 = 0;
  my ($j);

  while (defined($_=<$infh>)) {
    chomp;
    next if (/^\s*%%/);
    if ($_ eq '') {
      foreach $j (1..$k) {
	$kg[$i0] = $eos;
	$outfh->print(join("\t", @kg[map {($i0+$_) % $k} (1..$k)], 1), "\n");
	$i0 = ($i0+1) % $k;
      }
    } else {
      $kg[$i0] = $_;
      $outfh->print(join("\t", @kg[map {($i0+$_) % $k} (1..$k)], 1), "\n");
      $i0 = ($i0+1) % $k;
    }
  }

  if ($kg[($i0-1) % $k] ne $eos) {
    foreach $j (1..$k) {
      $kg[$i0] = $eos;
      $outfh->print(join("\t", @kg[map {($i0+$_) % $k} (1..$k)], 1), "\n");
      $i0 = ($i0+1) % $k;
    }
  }

  $infh->close();
}

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------

push(@ARGV,'-') if (!@ARGV);
our @infiles = $globargs ? (map {glob($_)} @ARGV) : @ARGV;
if ($listargs) {
  ##-- @infiles are file-lists: expand
  @listfiles = @infiles;
  @infiles = qw();
  foreach $listfile (@listfiles) {
    vmsg(1,"$prog: list: $listfile\n");
    open(LIST,"<$listfile")
      or die("$prog: open failed for list file '$listfile': $!");
    push(@infiles,map {chomp; $_} <LIST>);
    close(LIST);
  }
}

our $ttout = Lingua::TT::IO->toFile($outfile,encoding=>$encoding)
  or die("$0: open failed for output file '$outfile': $!");
our $outfh = $ttout->{fh};

##-- guts
foreach $ttfile (@infiles) {
  vmsg(2,"$prog: tt: $ttfile\n");
  processTTFile($ttfile,$outfh);
}


__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-1grams.perl - get unigrams from TT file(s)

=head1 SYNOPSIS

 tt-1grams.perl [OPTIONS] [TTFILE(s)]

 General Options:
   -help
   -version
   -verbose LEVEL

 Other Options:
   -union, -nounion     ##-- TTFILE argument(s) are/aren't really unigram files (default=no)
   -list , -nolist      ##-- TTFILE argument(s) are/aren't file-lists (default=no)
   -glob , -noglob      ##-- do/don't glob TTFILE argument(s) (default=do)
   -cmts , -nocmts      ##-- do/don't count comments (default=don't)
   -init 1GFILE         ##-- initialize unigrams from 1GFILE (default=none)
   -eos EOS             ##-- count eos as string EOS (default='')
   -noeos               ##-- do/don't count EOS at all
   -freqsort            ##-- sort output by frequency (default)
   -lexsort             ##-- sort output lexically
   -nosort              ##-- don't sort output at all
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
