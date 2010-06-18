#!/bin/sh -x

LANG=hr_HR.utf8 ./script/mojo_facets daemon --reload 2>&1 | tee /tmp/mojo_facets.log
