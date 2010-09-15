#!/usr/bin/perl -w

use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);
use File::Temp qw(tempfile);
#use File::Copy;

use lib '.';
use Lingua::TT;

##----------------------------------------------------------------------
## Globals
##----------------------------------------------------------------------

our $VERSION = "0.01";

##-- program vars
our $prog         = basename($0);
our $outfile      = '-';
our $verbose      = 0;

our $sort0   = 1; ##-- sort first input file?
our $sort1   = 1; ##-- sort other input file(s)?
our $keeptmp = 0; ##-- keep temp files?

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	  'help|h' => \$help,
	  #'man|m'  => \$man,
	  'version|V' => \$version,
	  'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'sort0|s0!' => \$sort0,
	   'sort1|s1!' => \$sort1,
	   'sort|s!' => sub { $sort0=$sort1=$_[1]; },
	   'keeptmp|keep|k!' => \$keeptmp,
	   'output|o=s' => \$outfile,
	  );

pod2usage({-msg=>'Not enough arguments specified!',-exitval=>1,-verbose=>0}) if (@ARGV < 1);
pod2usage({-exitval=>0,-verbose=>0}) if ($help);
#pod2usage({-exitval=>0,-verbose=>1}) if ($man);

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

## $tmpfile = fs_tmpfile()
sub fs_tmpfile {
  my ($tmpfh,$tmpfile) = tempfile("j123XXXXX", SUFFIX=>'.tmp', UNLINK=>!$keeptmp);
  $tmpfh->close;
  return $tmpfile;
}

## $tmpfile = filesort($infile)
sub filesort {
  my $infile = shift;
  my $tmpfile = fs_tmpfile();
  fs_system('sort',$infile,'-o',$tmpfile)==0
    or die("$prog: sort failed for '$infile' to '$tmpfile': $!");
  return $tmpfile;
}

## $rc = fs_system(@cmd)
sub fs_system {
  my @cmd = @_;
  vmsg(1,"$prog: ", join(' ', @cmd), "\n");
  return system(@cmd);
}

## $fh = fs_cmdfh($fspec)
##  + only one fh per time per script!
sub fs_cmdfh {
  my $fspec = shift;
  vmsg(1,"$prog: $fspec\n");
  open(MERGE,$fspec)
    or die("$prog: open failed for command \`$fspec`: $!");
  return \*MERGE;
}

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------

push(@ARGV,'-') if (@ARGV < 1);

##-- force strict lexical ordering
$ENV{LC_ALL} = 'C';

##-- sort input file(s)
our $file0 = shift(@ARGV);
our $file0s = $sort0 ? filesort($file0) : $file0;

our ($ofile);
foreach $i (0..$#ARGV) {
  $file1  = $ARGV[$i];
  $file1s = $sort1 ? filesort($file1) : $file1;
  $mergefh = fs_cmdfh("sort -m \"$file0s\" \"$file1s\" |");

  $ofile = $i==$#ARGV ? $outfile : fs_tmpfile;
  open(OUT, ">$ofile")
    or die("$prog: open failed for ".($i==$#ARGV ? '' : 'intermediate ')."output file '$ofile': $!");
  our ($lastkey,$lastf) = (undef,0);
  while (defined($_=<$mergefh>)) {
    if (/^$/ || /^%%/) {
      print OUT $_;
      next;
    }
    s/\r?\n?$//;
    if (/^(.*)\t([^\t]*)$/) {
      ($key,$f) = ($1,$2);
    } else {
      warn("$prog: could not parse merged line '$_'; skipping");
      next;
    }

    if (!defined($lastkey)) {
      ($lastkey,$lastf) = ($key,$f);
    }
    elsif ($key eq $lastkey) {
      $lastf += $f;
    }
    else {
      print OUT $lastkey, "\t", $lastf, "\n";
      ($lastkey,$lastf) = ($key,$f);
    }
  }
  if (defined($lastkey)) {
    print OUT $lastkey, "\t", $lastf, "\n";
  }

  close($mergefh);
  close(OUT);
}

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-123-join.perl - join verbose n-gram files using system sort & merge

=head1 SYNOPSIS

 tt-123-join.perl [OPTIONS] VERBOSE_123_FILE(s)...

 General Options:
   -help
   -version
   -verbose LEVEL

 Other Options:
   -sort0 , -nosort0  ##-- do/don't sort first input file    (default=do)
   -sort1 , -nosort1  ##-- do/don't sort other input file(s) (default=do)
   -sort  , -nosort   ##-- shortcut fot -[no]sort0 -[no]sort1
   -keep  , -nokeep   ##-- do/don't keep temporary files (default=don't)
   -output OUTFILE    ##-- set output file (default=STDOUT)

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

