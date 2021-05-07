#!/bin/sh -l

echo "Hello $1"

sendsync get templates
# echo "::set-output name=time::$time"