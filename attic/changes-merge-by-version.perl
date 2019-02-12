#!/usr/bin/perl -w

my $ver = '';
my @buf;

while (<>) {
  if (/^(?:\t\* )?v([0-9\.\-\_]+(?:_\w+)?)\s+(\S+)\s+(\S+)\s*$/) {
    my ($vnxt,$vdate,$vuser) = ($1,$2,$3);
    if ($vnxt ne $ver) {
      $ver = $vnxt;
      push(@buf,"\n",$_);
    }
    else {
      ;
      #push(@buf,"\t* <$vdate $vuser>\n");
    }
    next;
  }
  s{\s*[r[0-9]+\]}{}g;
  s{^(\t\*\s+)\Qv$ver\E\s*:?\s*}{$1};
  s{^\t\*\s*$}{};
  next if (/^\s*$/);
  push(@buf,$_);
}

##-- rewrap
for (my $i=1; $i < $#buf; ++$i) {
  next if ($buf[$i] =~ /^\s*$/ || $buf[$i] =~ /^v[0-9]/);
  if ($buf[$i+1] !~ /^\s*$/ && $buf[$i+1] !~ /^\s+[\*\+\-\~\:]\s/) {
    $buf[$i]   =~ s/\s*$//;
    $buf[$i+1] =~ s/^\s*/ /;
  }
}

print @buf;

