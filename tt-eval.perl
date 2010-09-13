#!/usr/bin/perl -w

use IO::File;
use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);
use Text::Balanced qw(extract_codeblock extract_quotelike extract_multiple);

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

our $encoding = undef; ##-- default encoding (?)
our $code_byline = undef;
our $doprint = 1;

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	  'help|h' => \$help,
	  #'man|m'  => \$man,
	  'version|V' => \$version,
	  'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'output|o=s' => \$outfile,
	   'encoding|e:s' => \$encoding,
	   'print|p!' => \$doprint,
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


##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
$encoding = undef if (defined($encoding) && ($encoding eq '' || $encoding eq 'raw'));
our $ttout = Lingua::TT::IO->new->toFile($outfile,encoding=>$encoding)
  or die("$prog: open failed for '$outfile': $!");
our $outfh = $ttout->{fh};
select($outfh);

##-- pre compile eval sub
##  + vars:
##      $ARGV : current file
##      $ttin : input Lingua::TT::IO object
##      $infh : input filehandle
##      $outfh: output filehandle (select()ed)
##      $_    : current line (chomped)
##      @_    : current line (split)
our ($infile,$ttin,$infh);
$code_byline = shift;
our $dofile_code = q(
sub {
  while (defined($_=<$infh>)) {
    s/\r?\n?$//s;
    @_ = split(/\t/,$_);
    ##-- BEGIN user code
    ).$code_byline.q(;
    ##-- END user code
    ).($doprint ? 'print join("\t",@_), "\n";' : '').q(
  }
});
vmsg(3,"$prog: DEBUG: User code sub\n",
     map {"$prog: DEBUG: $_\n"} split(/\n/,$dofile_code));
our $dofile_sub = eval $dofile_code;
die("$prog: could not pre-compile sub: $@") if ($@ || !$dofile_sub);


push(@ARGV,'-') if (!@ARGV);
foreach $infile (@ARGV) {
  $ttin = Lingua::TT::IO->fromFile($infile,encoding=>$encoding)
    or die("$prog: open failed for '$infile': $!");
  $infh = $ttin->{fh};

  $dofile_sub->();
  $ttin->close();
}

##-- cleanup
$ttout->close;

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-eval.perl - eval perl code for each line of .tt files

=head1 SYNOPSIS

 tt-eval.perl [OPTIONS] PERLCODE [TT_FILE(s)...]

 General Options:
   -help
   -version
   -verbose LEVEL

 Other Options:
   -encoding ENCODING ##-- set I/O encoding
   -output OUTFILE    ##-- set output file
   -noprint           ##-- don't implicitly print @_

 Perl Variables:
   $infile : current file
   $ttin   : input Lingua::TT::IO object
   $infh   : input filehandle
   $outfh  : output filehandle (select()ed)
   $_      : current line (chomped)
   @_      : current line fields (split): auto-printed

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

