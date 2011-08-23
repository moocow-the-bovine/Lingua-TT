#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::CDBFile;
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
our %dbf           = (utf8=>0);

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

	   ##-- I/O
	   'include-empty-analyses|allow-empty|empty!' => \$include_empty,
	   'output|o=s' => \$outfile,
	   'tt-encoding|encoding|te|ie|oe=s' => sub {$ttencoding=$_[1]; $dbf{utf8}=1;},
	   'utf8|u!' => sub {$ttencoding='utf8'; $dbf{utf8}=1; },
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
our $dbf = Lingua::TT::CDBFile->new(%dbf,file=>$dbfile)
  or die("$prog: could not open CDB file '$dbfile': $!");
our $data = $dbf->{data};
our $tied = $dbf->{tied};

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
    $a_dict = $dbf->fetch($text);
    $_ = join("\t", $text, (defined($a_in) ? $a_in : qw()), (defined($a_dict) && ($include_empty || $a_dict ne '') ? $a_dict : qw()))."\n";
  }
  continue {
    $outfh->print($_);
  }
  $ttin->close;
}

undef $data;
undef $tied;
$dbf->close;
$ttout->close;


__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-cdbapply.perl - apply CDB dictionary analyses to TT file(s)

=head1 SYNOPSIS

 tt-dbapply.perl [OPTIONS] CDB_FILE [TT_FILE(s)]

 General Options:
   -help

 I/O Options:
  -output FILE          ##-- default: STDOUT
  -encoding ENCODING    ##-- set I/O encoding (default: raw); implies UTF-8 db
  -empty   , -noempty   ##-- do/don't output empty analyses (default=don't)

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