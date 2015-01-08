#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use RocksDB;
use Fcntl;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $prog = basename($0);
our $VERSION  = "0.01";

our %dbf           = (utf8=>0);
our %apply_opts    = (allow_empty=>0);

our $ttencoding = undef;
our $dclass   = 'Lingua::TT::CDBFile';
our $outfile  = '-';

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   #'man|m'  => \$man,
	   #'version|V' => \$version,
	   #'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'include-empty-analyses|allow-empty|empty!' => \$apply_opts{allow_empty},
	   'output|o=s' => \$outfile,
	   'tt-encoding|encoding|te|ie|oe=s' => sub {$ttencoding=$_[1]; $dbf{utf8}=1;},
	   'utf8|u!'    => sub { $ttencoding=$_[1] ? 'utf8' : undef; $dbf{utf8}=$_[1]; },
	   'json|tj|j!' => sub { $ttencoding='utf8' if ($_[1]); $dclass='Lingua::TT::CDBFile'.($_[1] ? '::JSON' : ''); },
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>0,-msg=>'No CDB file specified!'}) if (!@ARGV);

##----------------------------------------------------------------------
## Subs


##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------

##-- open db
my $dbfile = shift(@ARGV);
our $dbf = RocksDB->new($dbfile, {create_if_missing=>0, read_only=>1})
  or die("$prog: could not open RocksDB file '$dbfile': $!");
our $tied = $dbf;
print STDERR "$prog: opened RocksDB file $dbfile.\n";

##-- open output handle
our $ttout = Lingua::TT::IO->toFile($outfile,encoding=>$ttencoding)
  or die("$0: open failed for '$outfile': $!");

##-- process inputs
foreach $infile (@ARGV ? @ARGV : '-') {
  $ttin = Lingua::TT::IO->fromFile($infile,encoding=>$ttencoding)
    or die("$0: open failed for '$infile': $!");

  ##-- apply
  #$dbf->apply($ttin,$ttout,%apply_opts) or die("$0: ", ref($dbf)."::apply() failed for '$infile': $!");
  my $infh  = $ttin->{fh};
  my $outfh = $ttout->{fh};
  my $fetch         = sub { $tied->get($_[0]) };
  my $include_empty = $apply_opts{allow_empty};
  my ($text,$a_in,$a_dict);
  my $apply = sub {
    ($text,$a_in) = split(/\t/,$_,2);
    $a_dict       = $fetch->($text);
    $_            = join("\t", $text, (defined($a_in) ? $a_in : qw()), (defined($a_dict) && ($include_empty || $a_dict ne '') ? $a_dict : qw()))."\n";
  };
  while (defined($_=<$infh>)) {
    next if (/^%%/ || /^$/);  ##-- ignore comments and blank lines (pass-through)
    chomp;
    $apply->();
  }
  continue {
    $outfh->print($_) or last;
  }

  $ttin->close;
}

undef($tied);
undef $dbf;
$ttout->close;


__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-rdbapply.perl - apply RocksDB dictionary analyses to TT file(s)

=head1 SYNOPSIS

 tt-rdbapply.perl [OPTIONS] ROCKSDB_FILE [TT_FILE(s)]

 General Options:
   -help

 I/O Options:
  -output FILE          ##-- default: STDOUT
  -encoding ENCODING    ##-- set I/O encoding (default: raw); implies UTF-8 db
  -utf8    , -noutf8    ##-- do/don't assume DB is UTF-8 (default=don't)
  -empty   , -noempty   ##-- do/don't output empty analyses (default=don't)
  -json    , -nojson    ##-- do/don't assume JSON values (default=don't)

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
