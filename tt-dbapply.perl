#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::DBFile;
use Fcntl;
use Encode qw(encode decode);

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $prog = basename($0);
our $VERSION  = "0.01";

our $include_empty = 0;
our %dbf           = (type=>'BTREE', flags=>O_RDWR, dbopts=>{cachesize=>'128M'});
our $dbencoding = undef;

our $ttencoding = undef;
our $outfile  = '-';

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
	   'db-cachesize|db-cache|cache|c=s' => \$dbf{dbopts}{cachesize},
	   'db-option|O=s' => $dbf{dbopts},
	   'db-encoding|dbe=s' => \$dbencoding,

	   ##-- I/O
	   'include-empty-analyses|allow-empty|empty!' => \$include_empty,
	   'output|o=s' => \$outfile,
	   'tt-encoding|te|ie|oe=s' => \$ttencoding,
	   'encoding|e=s' => sub {$ttencoding=$dbencoding=$_[1]},
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
our $dbf = Lingua::TT::DBFile->new(%dbf,file=>$dbfile)
  or die("$prog: could not open or create DB file '$outfile': $!");
our $data = $dbf->{data};
#our $tied = $dbf->{tied};

##-- open output handle
our $ttout = Lingua::TT::IO->toFile($outfile,encoding=>$ttencoding)
  or die("$0: open failed for '$outfile': $!");
our $outfh = $ttout->{fh};

##-- process inputs
our ($text,$a_in,$a_dict);
foreach $infile (@ARGV ? @ARGV : '-') {
  $ttin = Lingua::TT::IO->fromFile($infile,encoding=>$ttencoding)
    or die("$0: open failed for '$infile': $!");
  $infh = $ttin->{fh};

  while (defined($_=<$infh>)) {
    next if (/^%%/ || /^$/);
    chomp;
    ($text,$a_in) = split(/\t/,$_,2);
    if (defined($dbencoding)) {
      $a_dict = $data->{encode($dbencoding,$text)};
      $a_dict = decode($dbencoding,$a_dict) if (defined($a_dict));
    } else {
      $a_dict = $data->{$text};
    }
    $_ = join("\t", $text, (defined($a_in) ? $a_in : qw()), (defined($a_dict) && ($include_empty || $a_dict ne '') ? $a_dict : qw()))."\n";
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
  -output FILE          ##-- default: STDOUT
  -encoding ENCODING    ##-- default: UTF-8
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
