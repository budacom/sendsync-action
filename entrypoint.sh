#!/bin/sh -l

sendsync get template

git status templates/

templates=$(git status -s templates | cut -d' ' -f3 | cut -d'/' -f 2 | tr '\n' ',' | sed 's/,$//g')

echo "::set-output name=templates::${templates}"