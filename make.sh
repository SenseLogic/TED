#!/bin/sh
set -x
dmd -m64 ted.d
rm *.o
