#!/usr/bin/perl -w

use IO::File;
use Getopt::Long ':config'=>'no_ignore_case';
use Pod::Usage;
use File::Basename qw(basename dirname);

use lib '.';
use Lingua::TT;
use Lingua::TT::DB::File;
use Lingua::TT::Enum;
use Fcntl;

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION = "0.01";

##-- program vars
our $prog         = basename($0);
our $outfile_db   = undef; ##-- default: "$infile.db"
#our $outfile_enum = undef; ##-- default: "$infile.enum";
our $verbose      = 0;

our $encoding = undef; ##-- default encoding (?)
our $packfmt = 'N';
our $eos_str = '__$';
our $n = 1;
our $append = 0; ##-- are we adding to an existing db?

our %dbf    = (type=>'BTREE', flags=>O_RDWR|O_CREAT, dbopts=>{});
our $cachesize = 128*1024*1024;

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	  'help|h' => \$help,
	  'version|V' => \$version,
	  'verbose|v=i' => \$verbose,

	   ##-- Behavior
	   'n=i' => \$n,
	   'eos=s' => \$eos_str,
	   'encoding|enc|e=s' => \$encoding,

	   ##-- I/O
	   'db-hash|hash|dbh' => sub { $dbf{type}='HASH'; },
	   'db-btree|btree|bt|b' => sub { $dbf{type}='BTREE'; },
	   'pack|p:s' => \$packfmt,
	   'nopack|raw|strings|P' => sub { $packfmt=''; },
	   'append|add|a!' => \$add,
	   'truncate|trunc|clobber|t!' => sub { $add=!$_[1]; },
	   'db-cachesize|db-cache|cache|c=f' => \$cachesize,
	   'db-option|O=s' => $dbf{dbopts},
	   'output-db|odb|db|output|out|o=s' => \$outfile_db,
	   #'output-enum|oe|enum=s' => \$outfile_enum,
	  );

#pod2usage({-msg=>'Not enough arguments specified!', -exitval=>1, -verbose=>0}) if (@ARGV < 1);
pod2usage({-exitval=>0,-verbose=>0}) if ($help);
#pod2usage({-exitval=>0,-verbose=>1}) if ($man);

if ($version || $verbose >= 1) {
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
push(@ARGV,'-') if (!@ARGV);
our $ttin  = Lingua::TT::IO->new();

##-- defaults
$outfile_db   = $ARGV[0].".db"      if (!defined($outfile_db));
#$outfile_enum = $outfile_db.".enum" if (!defined($outfile_enum));

##-- open db
if (defined($cachesize) && $cachesize =~ /^\s*([\d\.\+\-eE]*)\s*([BKMG]?)\s*$/) {
  my ($cache,$suff) = ($1,$2);
  $suff = 'B' if (!defined($suff));
  $cache *= 1024 if ($suff eq 'K');
  $cache *= 1024*1024 if ($suff eq 'M');
  $cache *= 1024*1024 if ($suff eq 'G');
  $dbf{dbopts}{cachesize} = $cachesize;
}
$dbf{flags} |=  O_TRUNC if (!$add);
our $dbf = Lingua::TT::DB::File->new(%dbf,file=>$outfile_db)
  or die("$prog: could not open or create DB file '$outfile_db': $!");
our $data = $dbf->{data};

##-- create and possibly load enum
our $enum = Lingua::TT::Enum->new();
our %enum_io_opts = (defined($encoding) ? (encoding=>$encoding) : (raw=>1));
if (exists($data->{'$ENUM$'})) {
  $enum = $enum->loadNativeString($data->{'$ENUM$'},%enum_io_opts);
}
#die("$prog: coult not open or create enum file '$outfile_enum': $!") if (!$enum);

our $sym2id = $enum->{sym2id};
$enum->getId('');                     ##-- always map empty string (preferably to id 0)
our $eos_id = $enum->getId($eos_str); ##-- ... and eos to 1
our $eos_pk = $packfmt ? pack($packfmt,$eos_id) : $eos_str;

##-- nvars
our $joinchar = $packfmt ? '' : "\t";

foreach $ttfile (@ARGV) {
  vmsg(1,"$prog: processing $ttfile...\n");

  $ttin->fromFile($ttfile,encoding=>$encoding)
    or die("$prog: open failed for '$ttfile': $!");
  our $infh = $ttin->{fh};

  our @ngram = map {$eos_pk} (1..$n); ##-- ($packid,$packid,...)

  while (defined($_=<$infh>)) {
    next if (/^\%\%/); ##-- comment
    if (/^\s*$/) {
      count_eos();
      next;
    }

    chomp;
    if ($packfmt) {
      $tok_id = $enum->getId($_) if (!defined($tok_id=$sym2id->{$_}));
      $tok_pk = pack($packfmt,$tok_id);
    } else {
      $tok_pk = $_;
    }
    shift(@ngram);
    push(@ngram,$tok_pk);
    count_ngram();
  }
  ##-- count final eos
  count_eos();

  $ttin->close();
}

##-- subs: eos counting
sub count_eos {
  return if (!grep {$_ ne $eos_pk} @ngram);
  foreach (1..$n) {
    shift(@ngram);
    push(@ngram,$eos_pk);
    count_ngram();
  }
}


our ($_count);
sub count_ngram {
  #foreach (1..$n) {
  #  $ngram_pk = join($joinchar,,@ngram[(@ngram-$_)..$#ngram]);
  #  $data->{$ngram_pk} = ($c=$data->{$ngram_pk})++
  #}
  ##
  $ngram_pk = join($joinchar,@ngram);
  $data->{$ngram_pk} = ++($_count=$data->{$ngram_pk});
}

##-- cleanup: eos
#$eosN = join($joinchar, map {$eos_pk} (1..$n));
#$eos1 = $eos_pk;
#$data->{$eos1} = $data->{$eosN};
#delete($data->{$eosN});

##-- dump enum to db
if ($packfmt) {
  $data->{'$ENUM$'} = $enum->saveNativeString(%enum_io_opts);
}

##-- cleanup
$dbf->close();
#$enum->saveNativeFile($outfile_enum,(defined($encoding) ? (encoding=>$encoding) : (raw=>1)))
#  if ($packfmt);

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-ngramdb-add.perl - add n-gram counts for tt files to a Berkely db

=head1 SYNOPSIS

 tt-ngramdb-add.perl [OPTIONS] TT_FILE(s)

 General Options:
   -help                     ##-- this help message
   -version                  ##-- print version and exit
   -verbose LEVEL            ##-- set verbosity (0..?)

 Counting Options:
   -n   N                    ##-- maximum n-gram length
   -eos STRING               ##-- set EOS string (default='__$')

 I/O Options:
   -encoding ENCODING        ##-- set input encoding (default=none)
   -db-hash , -db-btree      ##-- set output DB type (default='HASH')
   -pack PACKFMT             ##-- set output pack format (default='N')
   -raw                      ##-- store raw strings instead of packed IDs
   -append , -clobber        ##-- do/don't append to existing file(s) (default:-add)
   -cache SIZE               ##-- set db cache size (with suffixes 'K','M','G')
   -db-option OPT=VAL        ##-- set DB option
   -output-db DBFILE         ##-- set output DB file (default=TT_FILE.db)
   -output-enum ENUMFILE     ##-- set output enum file (default=DBFILE.enum)

=cut

###############################################################
## OPTIONS AND ARGUMENTS
###############################################################
=pod

=head1 OPTIONS AND ARGUMENTS

Not yet written.

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
