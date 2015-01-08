#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Tie::LevelDB;
#use File::Copy;
#use File::Temp;
use Encode qw(encode decode);

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $prog = basename($0);
our $VERSION  = "0.01";

our $iencoding = undef;

our $include_empty = 0;
our %dbf      = (encoding=>undef);
our $outfile  = undef; ##-- default: INFILE.ldb

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   #'man|m'  => \$man,
	   #'version|V' => \$version,
	   #'verbose|v=i' => \$verbose,

	   ##-- db options
	   'append|add|a!' => \$append,
	   'truncate|trunc|clobber|t!' => sub { $append=!$_[1]; },
	   'include-empty-analyses|include-empty|empty!' => \$include_empty,

	   ##-- I/O
	   'input-encoding|iencoding|ie=s' => \$iencoding,
	   'output-db|output|out|o|odb|db=s' => \$outfile,
	   'output-db-encoding|db-encoding|dbe|oe=s' => \$dbf{encoding},
	   'encoding|e=s' => sub {$iencoding=$dbf{encoding}=$_[1]},
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
#pod2usage({-exitval=>0,-verbose=>0,-msg=>'No dictionary file specified!'}) if (!@ARGV);

##----------------------------------------------------------------------
## Subs

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------

push(@ARGV,'-') if (!@ARGV);

##-- defaults
$outfile = $ARGV[0].".ldb"  if (!defined($outfile));

##-- open db
our (%dbh);
our $dbf = tie(%dbh, 'Tie::LevelDB', $outfile)
  or die("$prog: could not open tie() LevelDB file '$outfile': $!");
our $tied = $dbf;
$tied->CLEAR() if (!$append);


##-- process input files
my $oencoding = (($dbf{encoding}||'raw') eq 'raw' ? undef : $dbf{encoding});
foreach $infile (@ARGV) {
  $ttin = Lingua::TT::IO->fromFile($infile,encoding=>$iencoding)
    or die("$0: open failed for '$infile': $!");
  $infh = $ttin->{fh};

  while (defined($_=<$infh>)) {
    next if (/^%%/ || /^$/);
    chomp;
    $_ = encode($oencoding,$_) if ($oencoding);
    ($text,$a_in) = split(/\t/,$_,2);
    next if (!defined($a_in) && !$include_empty); ##-- no entry for unanalyzed input
    $tied->STORE($text,$a_in);
  }
  $ttin->close;
}

undef $dbf;

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-dict2ldb.perl - convert a text dictionary to a LevelDB file

=head1 SYNOPSIS

 tt-dict2ldb.perl OPTIONS [TT_DICT_FILE(s)]

 General Options:
   -help

 DB_File Options:
  -append , -truncate   ##-- do/don't append to existing db (default=-append)
  -batch  , -nobatch    ##-- do/don't use batch-write mode (default=-batch)
  -empty  , -noempty    ##-- do/don't create records for empty analyses
  -db-encoding ENC      ##-- set DB internal encoding (default: null)

 I/O Options:
   -input-encoding ENC  ##-- set input encoding (default: null)
   -encoding ENC        ##-- alias for -input-encoding=ENC -db-encoding=ENC
   -output CDBFILE      ##-- default: STDOUT
   #-tmpfile TMPFILE     ##-- build temporary CDB as TMPFILE (default=CDBFILE.$$)

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
