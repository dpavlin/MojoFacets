#!/bin/sh -x

grep ajax.googleapis.com templates/layouts/ui.html.ep | cut -d\" -f4 | xargs wget --mirror --no-directories --directory-prefix=public/js/ 
