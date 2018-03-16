#!/bin/sh
set -x
../batched --verbose test.batched
../batched --verbose test_2.batched
../batched --verbose test_3.batched
../batched --verbose test_4.batched
../batched --verbose test_5.batched
