#!/bin/bash

source $CSAP_FOLDER/bin/csap-environment.sh

print_with_head "Generating token for accessing kubernetes dashboard"

adminUser=$(kubectl --namespace=kubernetes-dashboard get secret | grep admin-user | awk '{print $1}');

token=$(kubectl --namespace=kubernetes-dashboard describe secret $adminUser | grep "token:" | awk '{print $2}');

# DO NOT change this line - it is parsed in launch ui
echo "_CSAP_SCRIPT_OUTPUT_"
echo "$token"