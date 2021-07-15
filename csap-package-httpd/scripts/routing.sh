#!/bin/bash

source $CSAP_FOLDER/bin/csap-environment.sh

servicePort=${1:-8080} ;
tunnelPort=${2:-80} ;
createPort80Tunnel=${3:-false} ;

print_separator "CSAP Httpd Routing"

print_two_columns "servicePort" "$servicePort"
print_two_columns "tunnelPort" "$tunnelPort"
print_two_columns "createPort80Tunnel" "$createPort80Tunnel"

print_separator "iptables rules filtered with $servicePort"
iptables --table nat -L --line-number | grep $servicePort

lineNumbers=`iptables --table nat -L --line-number | grep $servicePort | awk '{ print $1}' | tac`

# for i in $( rulesWith$servicePort | tac ); do
for lineNumber in $lineNumbers ; do 
	print_separator "Deleting rule with line number: $lineNumber"
	iptables -t nat -D PREROUTING $lineNumber; 
done



primaryNetworkDevice=`route | grep default | awk '{ print $8}'`

if [[ $createPort80Tunnel == true ]] ; then
	
	print_separator adding new rule mapping $tunnelPort to $servicePort on $primaryNetworkDevice
	iptables -t nat -A PREROUTING -i $primaryNetworkDevice -p tcp --dport $tunnelPort -j REDIRECT --to-port $servicePort
	
	print_separator "iptables rules filtered with $servicePort"
	iptables --table nat -L --line-number | grep $servicePort
	
fi ;
