#!/bin/sh -l

git status
ls
sendsync get template

templates=$(git diff-files --name-only templates/ | cut -d '/' -f 2 | tr '\n' ',' | sed 's/,$//g')

echo "::set-output name=templates::$templates"