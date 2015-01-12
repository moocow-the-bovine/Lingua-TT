#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::DBFile;
use DB_File;
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
our %dbf           = (type=>'GUESS', flags=>O_RDONLY, encoding=>undef, dbopts=>{cachesize=>'128M'});
#our $dbencoding    = undef;

our $oencoding = undef;
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
	   'db-btree|btree|dbb' => sub { $dbf{type}='BTREE'; },
	   'db-guess|guess|dbg' => sub { $dbf{type}='GUESS'; },
	   'db-cachesize|db-cache|cache|c=s' => \$dbf{dbopts}{cachesize},
	   'db-option|O=s' => $dbf{dbopts},
	   'db-encoding|dbe|de=s' => \$dbf{encoding},

	   ##-- I/O
	   'output|o=s' => \$outfile,
	   'output-encoding|oencoding|oe=s' => \$oencoding,
	   'encoding|e=s' => sub {$dbf{encoding}=$oencoding=$_[1]},
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>0,-msg=>'No DB file specified!'}) if (!@ARGV);

##----------------------------------------------------------------------
## Subs


##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------


##-- open db
my $dbfile = shift(@ARGV);
our $dbf = Lingua::TT::DBFile->new(%dbf,file=>$dbfile)
  or die("$prog: could not open DB file '$dbfile': $!");
our $data = $dbf->{data};
our $tied = $dbf->{tied};

##-- open output handle
our $ttout = Lingua::TT::IO->toFile($outfile,encoding=>$oencoding)
  or die("$0: open failed for '$outfile': $!");
our $outfh = $ttout->{fh};

##-- dump DB
my ($key,$val,$status,$line);
$key=$val=0;
for ($status = $tied->seq($key,$val,R_FIRST);
     $status == 0;
     $status = $tied->seq($key,$val,R_NEXT))
  {
    #$line = $key."\t".$val."\n";
    #$line = decode($dbencoding,$line) if (defined($dbencoding));
    #$outfh->print($line);
    ##--
    $outfh->print($key,"\t",$val,"\n");
  }

undef($data);
undef($tied);
$dbf->close;
$ttout->close;


__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-db2dict.perl - convert DB dictionary to text

=head1 SYNOPSIS

 tt-db2dict.perl [OPTIONS] DB_FILE

 General Options:
   -help

 DB Options:
  -hash , -btree , -guess ##-- select DB output type (default='GUESS')
  -cache SIZE             ##-- set DB cache size (with suffixes K,M,G)
  -db-option OPT=VAL      ##-- set DB_File option
  -db-encoding ENC        ##-- set DB internal encoding (default: null)

 I/O Options:
   -output FILE           ##-- default: STDOUT
   -output-encoding ENC   ##-- output encoding (default: null)
   -encoding ENC          ##-- alias for -db-encoding=ENC -output-encoding=ENC

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
