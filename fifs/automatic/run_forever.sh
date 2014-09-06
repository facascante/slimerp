#!/bin/bash

#
# $Header: svn://svn/SWM/trunk/automatic/run_forever.sh 11342 2014-04-23 00:22:51Z drum $
#

# This script will take an argument command line and run it forever. Regardless of how the called script exits
# it will be restarted.
#

cmd=""
args=""
output_file=""

while getopts "c:a:o:" opt; do
  case $opt in
    c)
      echo "-c was triggered! arg = $OPTARG"
      cmd=$OPTARG
      ;;
    a)
      echo "-a was triggered! arg = $OPTARG"
      args="$args $OPTARG"
      ;;
    o)
      echo "-o was triggered! arg = $OPTARG"
      output_file=$OPTARG
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      ;;
  esac
done

if [ "$cmd" != "" ]; then
    # run the command forever.
    #
    while [ 1 == 1 ]; do
        if [ "$output_file" != "" ]; then
            $cmd $args >> $output_file 2>&1
        else
            $cmd $args 2>&1
        fi
        sleep 5
    done
fi
