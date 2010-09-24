#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::DB::File;
use Fcntl;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION  = "0.01";
our $encoding = undef;
our $outfile  = undef; ##-- default: INFILE.db

our $include_empty = 0;
our %dbf           = (type=>'BTREE', flags=>O_RDWR|O_CREAT, dbopts=>{});
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
	   'append|add|a!' => \$append,
	   'truncate|trunc|clobber|t!' => sub { $append=!$_[1]; },
	   'db-cachesize|db-cache|cache|c=s' => \$cachesize,
	   'db-option|O=s' => $dbf{dbopts},
	   'include-empty-analyses|include-empty|empty!' => \$include_empty,

	   ##-- I/O
	   'output-db|output|out|o|odb|db=s' => \$outfile,
	   'encoding|e=s' => \$encoding,
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
$outfile   = $ARGV[0].".db"  if (!defined($outfile));

##-- open db
if (defined($cachesize) && $cachesize =~ /^\s*([\d\.\+\-eE]*)\s*([BKMGT]?)\s*$/) {
  my ($size,$suff) = ($1,$2);
  $suff = 'B' if (!defined($suff));
  $size *= 1024    if ($suff eq 'K');
  $size *= 1024**2 if ($suff eq 'M');
  $size *= 1024**3 if ($suff eq 'G');
  $size *= 1024**4 if ($suff eq 'T');
  $dbf{dbopts}{cachesize} = $size;
}
$dbf{flags} |=  O_TRUNC if (!$append);
our $dbf = Lingua::TT::DB::File->new(%dbf,file=>$outfile_db)
  or die("$prog: could not open or create DB file '$outfile_db': $!");
our $data = $dbf->{data};
our $tied = $dbf->{tied};

##-- process input files
foreach $infile (@ARGV) {
  $ttin = Lingua::TT::IO->fromFile($infile,encoding=>$encoding)
    or die("$0: open failed for '$infile': $!");
  $infh = $ttin->{fh};

  while (defined($_=<$infh>)) {
    next if (/^%%/ || /^$/);
    chomp;
    ($text,$a_in) = split(/\t/,$_,2);
    next if (!defined($a_in) && !$include_empty); ##-- no entry for unanalyzed input
    $tied->put($text,$a_in)==0
      or die("$prog: DB_File::put() failed: $!");
  }
  $ttin->close;
}

$dbf->close;

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-dict2db.perl - convert a text dictionary to a DB_File

=head1 SYNOPSIS

 tt-dict2db.perl OPTIONS [TT_DICT_FILE(s)]

 General Options:
   -help

 DB_File Options:
  -hash   , -btree      ##-- select DB output type (default='BTREE')
  -append , -truncate   ##-- do/don't append to existing db (default=-append)
  -cache SIZE           ##-- set DB cache size (with suffixes K,M,G)
  -db-option OPT=VAL    ##-- set DB_File option
  -empty  , -noempty    ##-- do/don't create records for empty analyses

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
