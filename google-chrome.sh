#!/bin/sh -x

exec=`basename $0 | sed 's/.sh//'`
$exec --enable-extension-timeline-api --enable-apps http://localhost:3000
