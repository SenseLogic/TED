#!/bin/sh
set -x
dmd -m64 batched.d
rm *.o
