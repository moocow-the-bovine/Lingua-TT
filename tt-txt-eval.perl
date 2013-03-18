#!/usr/bin/perl -w

use lib '.';
use Lingua::TT;
use Lingua::TT::TextAlignment;
use Lingua::TT::Diff;

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
our $txtfile	  = undef;
our %ioargs       = (encoding=>'UTF-8');
our %diffargs     = (auxEOS=>0, auxComments=>1, diffopts=>'');
our %saveargs     = (shared=>1, context=>undef, syntax=>1);

our $dump_ttdiff = 0; ##-- dump/debug ttdiff?

##----------------------------------------------------------------------
## Command-line processing
##----------------------------------------------------------------------
our ($help,$version);
GetOptions(##-- general
	   'help|h' => \$help,
	   'version|V' => \$version,
	   'verbose|v=i' => \$verbose,

	   ##-- diff
	   'keep|K!'  => \$diffargs{keeptmp},
	   'diff-options|D' => \$diffargs{diffopts},
	   'minimal|d' => sub { $diffargs{diffopts} .= ' -d'; },

	   ##-- I/O
	   'ttdiff' => \$dump_ttdiff,
	   'output|out|o=s' => \$outfile,
	   'encoding|e=s' => \$ioargs{encoding},
	  );

pod2usage({-exitval=>0,-verbose=>0}) if ($help);
pod2usage({-exitval=>0,-verbose=>0,-msg=>'Not enough arguments specified!'}) if (@ARGV < 2);

if ($version || $verbose >= $vl_trace) {
  print STDERR "$prog version $VERSION by Bryan Jurish\n";
  exit 0 if ($version);
}


##-- sanity check(s) & overrides
if ($diffargs{keeptmp}) {
  $diffargs{tmpfile1} //= 'tmp_man.t0';
  $diffargs{tmpfile2} //= 'tmp_auto.t0';
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

##======================================================================
## precision, recall

## %prf = n2prf($ntp, $nfp, $nfn)
##      = n2prf($n12, $n_2, $n1_)
sub n2prf {
  my ($ntp,$nfp,$nfn) = map {$_||0} @_;
  my $nretr = $ntp+$nfp;
  my $nrel  = $ntp+$nfn;
  my $pr = ($nretr==0 ? 'nan' : ($ntp/$nretr));
  my $rc = ($nrel ==0 ? 'nan' : ($ntp/$nrel));
  my $F  = ($pr+$rc==0) ? 'nan' : (2 * $pr * $rc / ($pr + $rc));
  return (
	  "tp"=>"$ntp", "fp"=>"$nfp", "fn"=>"$nfn", "ret"=>"$nretr", "rel"=>"$nrel",
	  "pr"=>"$pr",  "rc"=>"$rc","F"=>"$F",
	 );
}

## $sum = lsum(@vals)
sub lsum {
  my $sum = 0;
  $sum += $_ foreach (@_);
  return $sum;
}

## $max = lmax(@vals)
sub lmax {
  my $max = -inf;
  foreach (@_) { $max=$_ if ($_>$max); }
  return $max;
}

## $maxlen = maxlen(@strings)
sub maxlen {
  return lmax map {length $_} @_;
}

## undef = dumptab($label, \%ev, @prefixes=sort keys %events)
sub dumptab {
  my ($ev,@prefixes) = @_;
  @prefixes  = (sort keys %$ev) if (!@prefixes);
  return if (!@prefixes); ##-- nothing to evaluate!
  my $plen   = maxlen('which',@prefixes);
  my $dlen   = maxlen 'tp', map {int($_)} map {@{$ev->{$_}}{qw(tp fp fn)}} @prefixes;
  my $flen   = 6;
  my $ffmt   = "%${flen}.2f";
  print
    (
     sprintf(" %-${plen}s  ".join('  ',map {"%${dlen}s"} qw(tp fp fn)).'  '.join('  ',map {"%${flen}s %%"} qw(pr rc F))."\n",
	     map {uc($_)} 'label', qw(tp fp fn), qw(pr rc F)),
     (map {
       my $prf = $_;
       sprintf(" %-${plen}s  ".join('  ',map {"%${dlen}d"} qw(tp fp fn)).'  '.join('  ',map {"$ffmt %%"} qw(pr rc F))."\n",
	       $_, @{$ev->{$prf}}{qw(tp fp fn)}, (map {100.0*$ev->{$prf}{$_}} qw(pr rc F)))
     } @prefixes),
     "\n"
    );
}

##======================================================================
## guts

## undef = count_shared($diff, $i1, $i2, \%events)
sub count_shared {
  my ($diff,$i1,$i2,$events) = @_;
  my $sw = ($diff->{seq1}[$i1]=~/^$/ ? 's' : 'w');
  push(@{$events->{$sw}{12}}, pack('NN',$i1,$i2));
}

## undef = count_single($diff,$which,$i,\%events)
sub count_single {
  my ($diff,$which,$i,$events) = @_;
  my $sw = ($diff->{"seq${which}"}[$i]=~/^$/ ? 's' : 'w');
  push(@{$events->{$sw}{$which}}, $i);
}

## \%filtered = filter_events_byaux($diff, \%events_all, $regex)
sub filter_events_byaux {
  my ($diff,$e_all,$regex,$default) = @_;
  my ($aux1,$aux2) = @$diff{qw(aux1 aux2)};
  my ($i1,$i2);
  my $filtered = {
		  12=>[grep {($i1,$i2)=unpack('NN',$_); $aux1->{$i1} && grep {$_ =~ $regex} @{$aux1->{$i1}}} @{$e_all->{12}}],
		  1 =>[grep {$i1=$_;                    $aux1->{$i1} && grep {$_ =~ $regex} @{$aux1->{$i1}}} @{$e_all->{1 }}],
		  2 =>[grep {$i2=$_;                    $aux2->{$i2} && grep {$_ =~ $regex} @{$aux2->{$i2}}} @{$e_all->{2 }}],
		 };
  return $filtered;
}

## \%filtered = filter_events_byaux_neg($diff, \%events_all, $regex)
sub filter_events_byaux_neg {
  my ($diff,$e_all,$regex) = @_;
  my ($aux1,$aux2) = @$diff{qw(aux1 aux2)};
  my ($i1,$i2);
  my $filtered = {
		  12=>[grep {($i1,$i2)=unpack('NN',$_); !$aux1->{$i1} || !grep {$_ =~ $regex} @{$aux1->{$i1}}} @{$e_all->{12}}],
		  1 =>[grep {$i1=$_;                    !$aux1->{$i1} || !grep {$_ =~ $regex} @{$aux1->{$i1}}} @{$e_all->{1 }}],
		  2 =>[grep {$i2=$_;                    !$aux2->{$i2} || !grep {$_ =~ $regex} @{$aux2->{$i2}}} @{$e_all->{2 }}],
		 };
  return $filtered;
}

## \%filtered = filter_events_byseq($diff, \%events_all, $regex)
sub filter_events_byseq {
  my ($diff,$e_all,$regex) = @_;
  my ($seq1,$seq2) = @$diff{qw(seq1 seq2)};
  my ($i1,$i2);
  my $filtered = {
		  12=>[grep {($i1,$i2)=unpack('NN',$_); $i1>0 && $seq1->[$i1] =~ $regex} @{$e_all->{12}}],
		  1 =>[grep {$i1=$_;                    $i1>0 && $seq1->[$i1] =~ $regex} @{$e_all->{1 }}],
		  2 =>[grep {$i2=$_;                    $i2>0 && $seq2->[$i2] =~ $regex} @{$e_all->{2 }}],
		 };
  return $filtered;
}

## \%events = get_eval_data($diff)
##  + returns \%events = {$sw => {12=>\@pairs, 1=>\@indices, 2=>\@indices}, ... }, where:
##    \@pairs is a list of pack('NN',$i1,$i2) pairs
##    $sw is 's' (sentences) or 'w' (tokens)
sub get_eval_data {
  my $diff = shift;
  my %events = (
		's'=>{"12"=>[], "1"=>[], "2"=>[]},
		'w'=>{"12"=>[], "1"=>[], "2"=>[]},
	       );

  my ($i1,$i2) = (0,0);
  my ($seq1,$seq2,$hunks) = @$diff{qw(seq1 seq2 hunks)};

  my ($hunk, $op,$min1,$max1,$min2,$max2, $fix);
  foreach $hunk (@$hunks) {
    ($op,$min1,$max1,$min2,$max2,$fix) = @$hunk;

    ##-- count shared preceding context
    count_shared($diff, $i1+$_, $i2+$_, \%events) foreach (0..($min1-$i1-1));

    ##-- count hunk data
    count_single($diff, '1', $_, \%events) foreach (($min1+0)..($max1+0));
    count_single($diff, '2', $_, \%events) foreach (($min2+0)..($max2+0));

    ##-- update current position
    ($i1,$i2) = ($max1+1,$max2+1);
  }

  ##-- count shared trailing context
  count_shared($diff, $i1+$_, $i2+$_, \%events) foreach (0..($#$seq1-$i1));

  ##-- special case: s_nopunct
  my $spunct_re = qr(^[\.\!\?\:]\t);
  $events{"s:nopunct"} = {
			   12=>[grep {($i1,$i2)=unpack('NN',$_); $i1>0 && $seq1->[$i1-1] !~ $spunct_re} @{$events{'s'}{12}}],
			   1 =>[grep {$i1=$_;                    $i1>0 && $seq1->[$i1-1] !~ $spunct_re} @{$events{'s'}{1 }}],
			   2 =>[grep {$i2=$_;                    $i2>0 && $seq2->[$i2-1] !~ $spunct_re} @{$events{'s'}{2 }}],
			  };

  ##-- special cases: tokens
  $events{"w~alpha"}   = filter_events_byseq($diff, $events{'w'}, qr(^[[:alpha:]]+\t), '');
  $events{"w~digit"}   = filter_events_byseq($diff, $events{'w'}, qr(^[[:digit:]]+\t), '');
  $events{"w~punct"}   = filter_events_byseq($diff, $events{'w'}, qr(^[[:punct:]]+\t), '');
  $events{"w:nospace"} = filter_events_byaux_neg($diff, $events{'w'}, qr(^%%\$c=\s+$), '%%$c= ');
  $events{"w:dotted"}  = filter_events_byseq($diff, $events{'w'}, qr(^[^\t]*[^[:punct:]][^\t]+[[:punct:]]\t), '');

  ##-- count events, convert to pr,rc,F
  my (%prf);
  foreach (values %events) {
    @$_{qw(tp fp fn)} = map {scalar(@$_)} @$_{qw(12 2 1)};
    %$_ = (%$_, n2prf(@$_{qw(tp fp fn)}));
  }

  return \%events;
}

##----------------------------------------------------------------------
## MAIN
##----------------------------------------------------------------------
our $rtt_man = shift;
our $rtt_tok = shift;

##-- get diff
our $diff = Lingua::TT::Diff->new(%diffargs);
vmsg1($vl_trace, "comparing MAN=$rtt_man AUTO=$rtt_tok ...");
$diff->compare($rtt_man, $rtt_tok, %ioargs)
  or die("$prog: diff->compare() failed: $!");

##-- dump ttdiff?
if ($dump_ttdiff) {
  vmsg1($vl_trace, "dumping ttdiff data to $outfile...");
  $diff->saveTextFile($outfile,%saveargs)
    or die("$prog: diff->saveTextFile() failed for '$outfile': $!");
}
else {
  vmsg1($vl_trace, "evaluating ...");
  my $events = get_eval_data($diff);

  vmsg1($vl_trace, "dumping evaluation data to $outfile ...");
  open(OUT, ">$outfile") or die("$prog: open failed for '$outfile': $!");
  select OUT;

  ##-- dump
  print "Manual = $rtt_man\nAutomatic = $rtt_tok\n";
  dumptab($events);

  close OUT;
}

vmsg1($vl_trace, "done.\n");

__END__

###############################################################
## pods
###############################################################

=pod

=head1 NAME

tt-txt-eval.perl - evaluate tokenizer output

=head1 SYNOPSIS

 tt-txt-eval.perl [OPTIONS] RTT_MANUAL RTT_AUTO

 General Options:
   -help
   -version
   -verbose LEVEL

 Diff Options:
   -D=DIFF_OPTS         # set underlying GNU diff option(s)
   -minimal , -d        # alias for -D="-d"
   -keep                # keep temporary files

 I/O Options:
   -output FILE         # output file (default: STDOUT)
   -encoding ENC        # I/O encoding (default: utf8)
   -ttdiff              # debug: dump raw TT::Diff data

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
