#!/usr/bin/perl -w

my ($id,$tag,$txt);
my %xlate = (
	     '-LRB-'=>'(', '-RRB-'=>')',
	     '-LSB-'=>'[', '-RSB-'=>']',
	     '-LCB-'=>'{', '-RCB-'=>'}',
	     ':pound:'=>'#',
	     ':at:'=>'@',
	     ':slash:'=>'/',
	     ':star:'=>'*',
	    );
while (<>) {
  chomp;
  print "%% Sentence $1\n" if (/^([^\(]+)::/);
  while (/\(([^\s\(\)]+)\s([^\(\)]+)\)/g) {
    ($tag,$txt) = ($1,$2);
    $tag=$txt=substr($tag,0,2)."SB-" if ($tag=~/^-[LR]RB-$/ && $txt=~/^-[LR]CB-$/);
    if ($txt =~ /:/) {
      $txt =~ s{:at:}{@}g;
      $txt =~ s{:pound:}{#}g;
      $txt =~ s{:slash:}{/}g;
      $txt =~ s{:star:}{*}g;
    }
    next if ($tag eq '-NONE-');
    $txt = $xlate{$txt} if (defined($xlate{$txt}));
    $tag = $xlate{$tag} if (defined($xlate{$tag}));
    print $txt, "\t", $tag, "\n";
  }
  print "\n";
}
