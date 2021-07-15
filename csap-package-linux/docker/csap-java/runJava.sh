#!/bin/bash

function print_with_head() { 
	echo -e "$LINE \n  $* \n$LINE"; 
}

function print_with_date() { 
	echo -e "$LINE `date '+%x %H:%M:%S %Nms'` host: '$HOSTNAME' user: '$USER' \n $* \n$LINE"; 
}

function print_line() { 
	echo -e "   $*" ;
}

print_with_head "Run user: `id` \n PATH: '$PATH'"

javaVersion=$(java -version 2>&1 | tail -1)
print_with_head "JAVA_HOME: '$JAVA_HOME' , java -version: '$javaVersion'"

print_with_head "JAVA_OPIONS: '$javaOptions'"

#startCommand=${startCommand:-java} ;
print_with_head "startCommand: '$startCommand' \njavaOptions:  '$javaOptions' \njavaTarget: '$javaTarget'"

eval $startCommand $javaOptions $javaTarget

#bash -c "$startCommand"
#java $JAVA_OPTIONS