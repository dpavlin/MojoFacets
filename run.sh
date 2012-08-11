#!/bin/sh -x

LANG=hr_HR.utf8 morbo ./script/mojo_facets 2>&1 | tee /tmp/mojo_facets.log
