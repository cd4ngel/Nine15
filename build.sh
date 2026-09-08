#!/bin/sh
set -eu

if [ -z "${THEOS:-}" ]; then
  echo "THEOS is not set. Install Theos and export THEOS=~/theos first." >&2
  exit 1
fi

make clean
make package FINALPACKAGE=1
echo "Package generated under ./packages/"
