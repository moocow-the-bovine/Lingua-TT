#!/bin/sh

if test -z "$*"; then
  echo "Usage: $0 TTFILE(s)"
  echo " + remove blank lines (EOS markers) from .tt files"
  exit 0;
fi

exec grep . "$@"
