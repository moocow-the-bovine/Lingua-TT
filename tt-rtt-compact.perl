#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::TextAlignment qw(:escape);

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

use strict;

##----------------------------------------------------------------------
## Globals

##-- verbosity levels
our $vl_silent = 0;
our $vl_error = 1;
our $vl_warn = 2;
our $vl_info = 3;
our $vl_trace = 4;

our $prog         = basename($0);
our $verbose      = $vl_info;
our $VERSION	  = 0.01;

our $outfile      = '-';
our %ioargs       = (encoding=>'UTF-8');
our $compact      = $prog =~ /(?:compact|compress)/ ? 1 : 0;

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
my ($help,$version);
GetOptions(##-- general
	   'help|h' => \$help,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- I/O
	   'output|o=s'   => \$outfile,
	   'encoding|e=s' => \$ioargs{encoding},
	   'compact|compress|C|z!' => \$compact,
	   'uncompact|uncompress|u|expand|x!' => sub {$compact=!$_[1]},
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
#pod2usage({-exitval=>0,-verbose=>0,-msg=>'Not enough arguments specified!'}) if (@ARGV < 2);

if ($version) {
  print STDERR "$prog version $VERSION by Bryan Jurish\n";
  exit 0 if ($version);
}

##----------------------------------------------------------------------
## messages
sub vmsg {
  my $level = shift;
  print STDERR @_ if ($verbose >= $level);
}
sub vmsg1 {
  my $level = shift;
  vmsg($level, "$prog: ", @_, "\n");
}

##----------------------------------------------------------------------
## Guts

##-------------------------------------------------------------
sub rtt_compact {
  my ($infh,$outfh) = @_;
  my ($ctxt, $r,$rt,$t,$rest);
  $ctxt = '';
  while (<$infh>) {
    s/\R\z//;
    if (/^%%\$c=(.*)/) {
      $ctxt .= $1;
      if ($ctxt !~ /^\s$/) {
	$outfh->print("%%\$c=$ctxt\n");
	$ctxt = '';
      }
    }
    elsif (/^%%/ || /^$/) {
      $outfh->print($_,"\n");
    }
    else {
      ($r,$t,$rest) = split(/\t/,$_,3);
      $r //= '';
      $t //= '';
      ($rt =  unescape_rtt($r)) =~ s/^\s+//;
      $rt  =~ s/\s+$//;
      $rt  =~ s/\s+/_/g;
      if ($rt ne $t) {
	##-- non-literal match (AFTER decoding and space-underscore normalization): encode it as "RAW $= TEXT"
	$r .= " \$= ".escape_rtt($t);
      }
      $outfh->print("$ctxt$r", (defined($rest) ? "\t$rest" : qw()), "\n");
      $ctxt = '';
    }
  }
  return 1;
}

##-------------------------------------------------------------
sub rtt_expand {
  my ($infh,$outfh) = @_;

  my ($rt,$r,$t,$rest,$ctxt);
  while (<$infh>) {
    if (/^%%/ || /^$/) {
      $outfh->print($_);
      next;
    }

    s/\R\z//;
    ($rt,$rest) = split(/\t/,$_,2);
    $ctxt = ($rt =~ s/^(\s+)// ? $1 : '');
    if ($rt =~ /^(.*) \$=\s*(.*)$/) {
      ($r,$t) = ($1,unescape_rtt($2));
    } else {
      $t = unescape_rtt($r = $rt);
      $t =~ s/\s+/_/g;
    }
    $outfh->print(
		  ($ctxt ne '' ? ("%%\$c=", escape_rtt($ctxt), "\n") : qw()),
		  join("\t",$r,$t,(defined($rest) ? $rest : qw())), "\n",
		 );
  }
  return 1;
}



##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
my $infile = shift // '-';
my $ttin = Lingua::TT::IO->open("<",$infile,%ioargs)
  or die("$prog: open failed for $infile: $!");

my $ttout = Lingua::TT::IO->open(">",$outfile,%ioargs)
  or die("$prog: open failed for $outfile: $!");

if ($compact) {
  rtt_compact($ttin->{fh},$ttout->{fh});
} else {
  rtt_expand($ttin->{fh},$ttout->{fh});
}
$ttin->close();
$ttout->close();

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-rtt-compact.perl - compact an RTT file to a RTTZ file

=head1 SYNOPSIS

 tt-rtt-compact.perl [OPTIONS] [RTT[Z]_FILE=-]

 General Options:
   -help
   -version
   -verbose LEVEL

 I/O Options:
   -output FILE         # output file in RTT format (default: STDOUT)
   -encoding ENC        # input encoding (default: utf8) [output is always utf8]
   -compact  , -expand  # compact-mode (rtt->rttz) or expand-mode (rttz->rtt)?

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
