#!/bin/bash

#source $STAGING/bin/csap-env.sh


print_separator "Creating logging mountpoints"

volumeBasePath=${volume_os:-not-specified} ;
if [ "$volumeBasePath" == "not-specified" ] ; then
	print_error "volumeBasePath not set" ;
	exit 99;
fi ;

run_using_root mkdir --parents --verbose $volumeBasePath-0
run_using_root mkdir --parents --verbose $volumeBasePath-1
run_using_root mkdir --parents --verbose $volumeBasePath-2
	