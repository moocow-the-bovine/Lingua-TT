#!/bin/sh

for f in "$@"; do
  echo "%% File: $f"
  cat "$f"
  ##-- add implicit EOS between files (use tt-eosnorm.perl to normalize)
  echo ""
done
