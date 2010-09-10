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
our $enum_infile  = undef;
our $enum_ids     = 0;

our $want_cmts = 1;
our $eos       = '';
our $sort      = 'freq'; ##-- one of qw(freq lex none)

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'output|o=s' => \$outfile,
	   'encoding|e=s' => \$encoding,
	   'comments|cmts|c!' => \$want_cmts,
	   'eos|s:s' => \$eos,
	   'no-eos|noeos|S' => sub { undef $eos; },
	   #'sort=s' => \$sort,
	   'nosort' => sub { $sort='none'; },
	   'freqsort|fsort|fs' => sub {$sort='freq'; },
	   'lexsort|lsort|ls' => sub {$sort='lex'; },
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
## MAIN
##----------------------------------------------------------------------

our %wf = qw(); ##-- $text => $freq, ...
our $ug = Lingua::TT::Unigrams->new(wf=>\%wf);

our ($ttin);
push(@ARGV,'-') if (!@ARGV);
foreach $infile (@ARGV) {
  $ttin = Lingua::TT::IO->fromFile($infile,encoding=>$encoding)
    or die("$0: open failed for input file '$infile': $!");
  my $infh = $ttin->{fh};

  while (defined($_=<$infh>)) {
    chomp;
    next if ((/^\s*%%/ && !$want_cmts));
    $_ = $eos if ($_ eq '');
    next if (!defined($_));
    ++$wf{$_};
  }
  $infh->close();
}

##-- save
$ug->saveNativeFile($outfile,sort=>$sort,encoding=>$encoding)
  or die("$prog: save failed to '$outfile': $!");

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
   -cmts , -nocmts      ##-- do/don't count comments (default=don't)
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
