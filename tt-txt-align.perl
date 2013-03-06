#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::Diff;

use Getopt::Long qw(:config no_ignore_case);
use Pod::Usage;
use File::Basename qw(basename);

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
our $outfmt       = 'DEFAULT';
our %ioargs       = (encoding=>'UTF-8');
our %saveargs     = (shared=>1, context=>undef, syntax=>1);
our %diffargs     = (auxEOS=>0, auxComments=>1, diffopts=>'');
our %fmtargs	  = (
		     'xmlc'    => 'c',    ##-- e.g. 'c', '' for none
		     'xmlroot' => 'doc',  ##-- e.g. 'doc', '' for none
		    );

our %outfmts = (
		'none' => 'null',
		'diff' => 'ttdiff',
		'tt' => 'rtt',
		'ttc' => 'rtt',
		'DEFAULT' => 'rtt',
	       );

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
GetOptions(##-- general
	   'help|h' => \$help,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- diff
	   'keep|K!'  => \$diffargs{keeptmp},
	   'diff-options|D' => \$diffargs{diffopts},
	   'fmt-options|F=s'  => \%fmtargs,
	   'minimal|d' => sub { $diffargs{diffopts} .= ' -d'; },

	   ##-- I/O
	   'format|f=s' => \$outfmt,
	   'output|o=s' => \$outfile,
	   'encoding|e=s' => \$ioargs{encoding},
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>0,-msg=>'Not enough arguments specified!'}) if (@ARGV < 2);

if ($version || $verbose >= 2) {
  print STDERR "$prog version $VERSION by Bryan Jurish\n";
  exit 0 if ($version);
}


##-- sanity check(s) & overrides
if ($diffargs{keeptmp}) {
  $diffargs{tmpfile1} //= 'tmp_txt.t0';
  $diffargs{tmpfile2} //= 'tmp_tt.t0';
}

##-- check for known output format
my $outfmt0 = $outfmt;
my $outsub  = undef;
$outfmt = 'DEFAULT' if (!defined($outfmt));
$outfmt = $outfmts{$outfmt} while (defined($outfmts{$outfmt}));
pod2usage({-exitval=>1,-verbose=>0,-msg=>"unknown output format '$outfmt0'"})
  if ( !($outsub=UNIVERSAL::can('main',"save_$outfmt")) );

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
## Output

##--------------------------------------------------------------
## utils: compute $char_i => $tt_i map

## \$c2t = get_c2t_vec($diff);
## \$c2t = get_c2t_vec($diff,\$c2t);
##  + get vec()-style vec s.t. ($ti == vec($c2t, $ci, 32)) iff char $::ttchars[$ci] aligns to token $::ttlines->[$ti-1]
sub get_c2t_vec {
  my ($diff,$vecr) = @_;
  do { my $vec = ''; $vecr = \$vec; } if (!$vecr);

  my ($i1,$i2) = (0,0);
  my ($fmin1,$fmax1,$fmin2,$fmax2); ##-- finite-context vars
  my ($seq1,$seq2,$hunks) = @$diff{qw(seq1 seq2 hunks)};
  my ($hunk, $op,$min1,$max1,$min2,$max2,$fix,$cmt, $addr);

  my ($j);
  my $nil  = [];
  foreach $hunk (@{$diff->{hunks}}) {
    ($op,$min1,$max1,$min2,$max2,$fix,$cmt) = @$hunk;

    ##-- full context: preceding context
    foreach $j (0..($min1-$i1-1)) {
      vec($$vecr, $i1+$j, 32) = $1 if (($seq2->[$i2+$j]//'') =~ /\t([0-9]+)$/);
    }

    ##-- non-identity hunk: ignore

    ##-- update current position counters
    ($i1,$i2) = ($max1+1,$max2+1);
  }

  ##-- trailing context
  foreach $j (0..($#$seq1-$i1)) {
    vec($$vecr, $i1+$j, 32) = $1 if (($seq2->[$i2+$j]//'') =~ /\t([0-9]+)$/);
  }

  return $vecr;
}

##--------------------------------------------------------------
## utils: compute $char_i => $tt_i map

## (\$minr,\$maxr) = get_w_minmax(\$c2t);
##  + see get_c2t_vec() for details on arg \$c2t
##  + get vec()-style vecs s.t.
##     $ci==vec($minr, $ti, 32) iff $ci==  min i with vec($c2t,i,32)==$ti
##     $ci==vec($maxr, $ti, 32) iff $ci==1+max i with vec($c2t,i,32)==$ti
sub get_w_minmax {
  my ($c2tr,$minr,$maxr) = @_;
  do { my $min = ''; $minr = \$min; } if (!$minr);
  do { my $max = ''; $maxr = \$max; } if (!$maxr);
  my $got = '';

  use bytes;
  my ($ti,$ci);
  foreach $ci (0..$#::txtchars) {
    $ti = vec($$c2tr,$ci,32);
    if (!vec($got,$ti,1)) {
      vec($$minr,$ti,32) = $ci;
      vec($got,$ti,1) = 1;
    }
    vec($$maxr,$ti,32) = $ci+1;
  }

  return ($minr,$maxr);
}

##--------------------------------------------------------------
## output: null
sub save_null {
  return 1;
}

##--------------------------------------------------------------
## output: tt-diff
sub save_ttdiff {
  my ($diff,$filename) = @_;
  if (!$fmtargs{rawdiff}) {
    my $used = '';
    my ($tti);
    foreach (@{$diff->{seq2}}) {
      next if (/^\%\%/ || /^$/);
      if (/\t([0-9]+)$/ && !vec($used,$1,1)) {
	$tti = $1;
	$_ .= "\t".$::ttlines->[$tti-1];
	vec($used,$tti,1) = 1;
      }
    }
  }
  $diff->saveTextFile($filename, %saveargs,%fmtargs)
    or die("$prog: diff->saveTextFile() failed for '$filename': $!");
}

##--------------------------------------------------------------
##-- output: tt +text-comments
sub save_rtt {
  my ($diff,$filename) = @_;
  my $fh = IO::File->new(">$filename")
    or die("$prog: save_rtt(): open failed for '$filename': $!");
  binmode($fh, ":encoding($ioargs{encoding})") if ($ioargs{encoding});

  ##-- get ci-to-ti map
  my $c2tr = get_c2t_vec($diff);

  ##-- get min-,max-character-index for each tt-line index
  my ($wminr,$wmaxr) = get_w_minmax($c2tr);

  ##-- churn through, tt-primary
  my $cseq = $diff->{seq1};
  my ($ti,$ci) = (0,0);
  my ($ci_min,$ci_max);
  foreach $ti (0..$#$ttlines) {
    ##-- get token limits
    $ci_min = vec($$wminr,$ti+1,32);
    $ci_max = vec($$wmaxr,$ti+1,32);

    ##-- leading text data?
    if ($ci < $ci_min) {
      $fh->print("%%\$c=", @$cseq[$ci..($ci_min-1)], "\n");
      $ci = $ci_min;
    }

    if ($ci_min>=$ci_max) {
      ##-- no character data for this tt-line (comment or EOS): just dump the tt-line
      $fh->print($ttlines->[$ti], "\n");
    } else {
      ##-- character data present: snarfle it up (greedy)
      $fh->print(@$cseq[$ci_min..($ci_max-1)], "\t", $ttlines->[$ti], "\n");

      ##-- update counters
      $ci = $ci_max;
    }
  }

  ##-- trailing text data?
  $fh->print("%%\$c=", @$cseq[$ci..$#$cseq], "\n") if ($ci <= $#{$cseq});

  ##-- all done
  close($fh);
}


##--------------------------------------------------------------
## output: XML +c
sub save_xml {
  my ($diff,$filename) = @_;
  my $fh = IO::File->new(">$filename")
    or die("$prog: save_rtt(): open failed for '$filename': $!");
  binmode($fh, ":encoding($ioargs{encoding})") if ($ioargs{encoding});

  if ($::fmtargs{xmlroot}) {
    $fh->print('<?xml version="1.0"', ($ioargs{encoding} ? " encoding=\"$ioargs{encoding}\"" : qw()), "?>\n",
	       "<$::fmtargs{xmlroot}>\n"
	      );
  }

  ##-- get ci-to-ti map
  my $c2tr = get_c2t_vec($diff);

  ##-- get min-,max-character-index for each tt-line index
  my ($wminr,$wmaxr) = get_w_minmax($c2tr);

  my %cxlate = (
		"\\n" => "\n",
		"\\t" => "\t",
	       );

  ##-- churn through, tt-primary
  my $xmlc = $::fmtargs{xmlc};
  my $endl = $xmlc ? "\n" : '';
  my $cseq = $diff->{seq1};
  my ($ti,$ci) = (0,0);
  my ($ci_min,$ci_max);
  my ($s_open,$cmt);
  foreach $ti (0..$#$ttlines) {
    ##-- get token limits
    $ci_min = vec($$wminr,$ti+1,32);
    $ci_max = vec($$wmaxr,$ti+1,32);

    ##-- leading text data?
    if ($ci < $ci_min) {
      $fh->print(($xmlc ? "<$xmlc>" : qw()),
		 xmlescape(join('',map {$cxlate{$_}//$_} @$cseq[$ci..($ci_min-1)])),
		 ($xmlc ? "</$xmlc>" : qw()),
		 $endl
		);
      $ci = $ci_min;
    }

    if ($ci_min>=$ci_max) {
      ##-- no character data for this tt-line (comment or EOS): just dump the item
      if ($ttlines->[$ti] =~ /^%%(.*)$/) {
	$cmt = $1;
	$fh->print("<!--",
		   ($cmt =~ /^ / ? qw() : ' '),
		   xmlescape($cmt),
		   ($cmt =~ / $/ ? qw() : ' '),
		   "-->",
		   $endl);
      }
      elsif ($ttlines->[$ti] =~ /^$/) {
	$fh->print("</s>$endl") if ($s_open);
	$s_open = 0;
      }
      else {
	$fh->print("<w tt=\"", xmlescape($ttlines->[$ti]), "\"/>$endl");
      }
    } else {
      ##-- character data present: snarfle it up (greedy)
      $fh->print(
		 ($s_open ? '' : "<s>$endl"),
		 "<w tt=\"", xmlescape($ttlines->[$ti]),"\">", @$cseq[$ci_min..($ci_max-1)], "</w>$endl"
		);
      $s_open = 1;

      ##-- update counters
      $ci = $ci_max;
    }
  }

  ##-- close final sentence
  $fh->print($s_open ? "</s>$endl" : qw());

  ##-- trailing text data?
  $fh->print(($xmlc ? "<$xmlc>" : qw()),
	     xmlescape(join('', map {$cxlate{$_}//$_} @$cseq[$ci..$#$cseq])),
	     ($xmlc ? "</$xmlc>" : qw()),
	     $endl);

  ##-- close wrapper element?
  $fh->print("</$::fmtargs{xmlroot}>\n") if ($::fmtargs{xmlroot});


  ##-- all done
  close($fh);
}

##--
my ($_esc);
sub xmlescape {
  $_esc=shift;
  $_esc=~s/([\&\'\"\<\>\r\n\t])/'&#'.ord($1).';'/ge;
  return $_esc;
}



##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
our ($txtfile,$ttfile) = @ARGV;

##-- get raw text buffer
vmsg1($vl_info, "buffering text data from $txtfile ...");
my ($txtbuf);
{
  local $/=undef;
  open(TXT,"<:encoding($ioargs{encoding})",$txtfile)
    or die("$prog: open failed for $txtfile: $!");
  $txtbuf=<TXT>;
  close(TXT);
}

##-- get raw tt data
vmsg1($vl_info, "buffering TT data from $ttfile ...");
my $ttio  = Lingua::TT::IO->fromFile($ttfile,%ioargs)
  or die("$0: could not open Lingua::TT::IO from $ttfile: $!");
our $ttlines = $ttio->getLines();

##-- split to characters
vmsg1($vl_info, "extracting text characters ...");
our @txtchars = map {s/\R/\\n/g; s/\t/\\t/g; $_} split(//,$txtbuf);

vmsg1($vl_info, "extracting token characters ...");
my ($l,$w,$w0,@c);
our @ttchars  = (
		 map {
		   $w = $ttlines->[$l=$_];
		   chomp($w);
		   ($w0 = $w) =~ s/\t.*$//;
		   if ($w =~ /^\%\%/) { @c = ($w); }
		   elsif ($w =~ /^$/) { @c = ("%%\$EOS"); }
		   else { @c = map {"$_\t".($l+1)} split(//,$w0); }
		   @c
		 } (0..$#$ttlines)
		);


##-- run tt-diff comparison
vmsg1($vl_info, "comparing ...");
our $diff = Lingua::TT::Diff->new(%diffargs);
$diff->compare(\@txtchars,\@ttchars)
  or die("$0: diff->compare() failed: $!");
@$diff{qw(file1 file2)} = ("$txtfile (text)", "$ttfile (tokens)");

##-- dump
vmsg1($vl_info, "saving to $outfile using format '$outfmt'...");
$outsub->($diff,$outfile);
vmsg1($vl_info, "done.\n");

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-txt-align.perl - align raw-text and TT-format files

=head1 SYNOPSIS

 tt-txt-align.perl [OPTIONS] TEXT_FILE TT_FILE

 General Options:
   -help
   -version
   -verbose LEVEL

 Diff Options:
   -keep   , -nokeep    # do/don't keep temp files (default=don't)
   -minimal             # alias for -D='-d'
   -D DIFF_OPTIONS      # pass DIFF_OPTIONS to GNU diff
   -F FMT_OPTION=VAL	# additional format-specific options (e.g. xmlc=ELT, xmlroot=ELT, ...)

 I/O Options:
   -output FILE         # output file (default: STDOUT)
   -encoding ENC        # input encoding (default: utf8) [output is always utf8]
   -format FMT		# use output format FMT {ttdiff,rtt,xml,...} (default: rtt)

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
