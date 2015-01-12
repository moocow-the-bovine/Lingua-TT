#!/usr/bin/perl -w

use IO::File;
use Getopt::Long ':config'=>'no_ignore_case';
use Pod::Usage;
use File::Basename qw(basename dirname);

use lib '.';
use Lingua::TT;
use Fcntl;

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION = "0.01";

##-- program vars
our $prog         = basename($0);
our $outfile      = '-';
our $verbose      = 0;

our $eos	  = '__$';
our $n  	  = 2;

our $fieldsep = "\x{0b}"; ##-- field separator (internal); 0x0b=VT (vertical tab)
our $wordsep  = "\t";     ##-- word separator (external)

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	  'help|h' => \$help,
	  'version|V' => \$version,
	  'verbose|v=i' => \$verbose,

	   ##-- Behavior
	   'eos|e=s' => \$eos,
	   'n|k=i' => \$n,
	   'field-separator|fs|f=s' => \$fieldsep,
	   'record-separator|rs|r|word-separator|ws|w=s' => \$wordsep,

	   ##-- I/O
	   'output|out|o=s' => \$outfile,
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
foreach my $ttfile (@ARGV) {
  vmsg(1,"$prog: processing $ttfile...\n");

  our $ttin = Lingua::TT::IO->fromFile($ttfile,encoding=>undef)
    or die("$prog: open failed for '$ttfile': $!");
  our $infh = $ttin->{fh};

  my $last_was_eos = 1;
  my @ng = map {$eos} (1..$n);
  print join($wordsep,@ng), "\n";

  while (defined($_=<$infh>)) {
    next if (/^\%\%/); ##-- comment or blank line
    chomp;

    if (/^$/) {
      ##-- eos: flush n-gram window
      next if ($last_was_eos);
      foreach (1..$n) {
	shift(@ng);
	push(@ng,$eos);
	print join($wordsep,@ng), "\n";
      }
      $last_was_eos = 1;
    } else {
      s{\t}{$fieldsep}g if ($fieldsep ne "\t");
      shift(@ng);
      push(@ng,$_);
      print join($wordsep,@ng), "\n";
      $last_was_eos = 0;
    }
  }

  $ttin->close();

  next if ($last_was_eos);
  foreach (1..$n) {
    shift(@ng);
    push(@ng,$eos);
    print join($wordsep,@ng), "\n";
  }
}

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-ngrams.perl - compute raw n-grams from a tt-file

=head1 SYNOPSIS

 tt-ngrams.perl [OPTIONS] TT_FILE(s)...

 General Options:
   -help                     ##-- this help message
   -version                  ##-- print version and exit
   -verbose LEVEL            ##-- set verbosity (0..?)

 I/O Options:
   -n N                      ##-- set n-gram length (default=2)
   -fs FIELDSEP              ##-- set word-internal field separator (default=VTAB)
   -ws WORDSEP               ##-- set word separator (default=TAB)
   -eos EOS	             ##-- set EOS string (default=__$)
   -output OUTFILE           ##-- set output file (default=STDOUT)

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

Bryan Jurish E<lt>moocow@cpan.orgE<gt>

=head1 SEE ALSO

perl(1).

=cut

