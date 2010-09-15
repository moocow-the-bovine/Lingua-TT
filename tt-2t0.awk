#!/usr/bin/awk -f

BEGIN	{ FS="\t"; OFS="\t" }
/^$/    { print $0; next }
/^%%/   { print $0; next }
{ print "-",$0 }
