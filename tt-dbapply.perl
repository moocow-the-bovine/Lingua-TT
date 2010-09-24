#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $prog = basename($0);
our $VERSION  = "0.01";
our $encoding = undef;
our $outfile  = '-';

our $include_empty = 0;
our %dbf           = (type=>'BTREE', flags=>O_RDWR, dbopts=>{});
our $cachesize     = '128M';

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   #'man|m'  => \$man,
	   #'version|V' => \$version,
	   #'verbose|v=i' => \$verbose,

	   ##-- db options
	   'db-hash|hash|dbh' => sub { $dbf{type}='HASH'; },
	   'db-btree|btree|bt|b' => sub { $dbf{type}='BTREE'; },
	   'db-cachesize|db-cache|cache|c=s' => \$cachesize,
	   'db-option|O=s' => $dbf{dbopts},

	   ##-- I/O
	   'output|o=s' => \$outfile,
	   'encoding|e=s' => \$encoding,
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>0,-msg=>'No dictionary file specified!'}) if (!@ARGV);

##----------------------------------------------------------------------
## Subs


##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------


##-- open db
my $dbfile = shift(@ARGV);
if (defined($cachesize) && $cachesize =~ /^\s*([\d\.\+\-eE]*)\s*([BKMGT]?)\s*$/) {
  my ($size,$suff) = ($1,$2);
  $suff = 'B' if (!defined($suff));
  $size *= 1024    if ($suff eq 'K');
  $size *= 1024**2 if ($suff eq 'M');
  $size *= 1024**3 if ($suff eq 'G');
  $size *= 1024**4 if ($suff eq 'T');
  $dbf{dbopts}{cachesize} = $size;
}
our $dbf = Lingua::TT::DB::File->new(%dbf,file=>$dbfile)
  or die("$prog: could not open or create DB file '$outfile': $!");
our $data = $dbf->{data};
#our $tied = $dbf->{tied};

##-- open output handle
our $ttout = Lingua::TT::IO->toFile($outfile,encoding=>$encoding)
  or die("$0: open failed for '$outfile': $!");
our $outfh = $ttout->{fh};

##-- process inputs
our ($text,$a_in,$a_dict);
foreach $infile (@ARGV ? @ARGV : '-') {
  $ttin = Lingua::TT::IO->fromFile($infile,encoding=>$encoding)
    or die("$0: open failed for '$infile': $!");
  $infh = $ttin->{fh};

  while (defined($_=<$infh>)) {
    next if (/^%%/ || /^$/);
    chomp;
    ($text,$a_in) = split(/\t/,$_,2);
    $a_dict = $data->{$text};
    $_ = join("\t", $text, (defined($a_in) ? $a_in : qw()), (defined($a_dict) ? $a_dict : qw()))."\n";
  }
  continue {
    $outfh->print($_);
  }
  $ttin->close;
}

$dbf->close;
$ttout->close;


__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-dbapply.perl - apply DB dictionary analyses to TT file(s)

=head1 SYNOPSIS

 tt-dbapply.perl [OPTIONS] DB_FILE [TT_FILE(s)]

 General Options:
   -help

 DB Options:
  -hash   , -btree      ##-- select DB output type (default='BTREE')
  -cache SIZE           ##-- set DB cache size (with suffixes K,M,G)
  -db-option OPT=VAL    ##-- set DB_File option

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
