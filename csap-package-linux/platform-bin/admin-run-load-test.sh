#!/bin/bash
#
#
#
# set -o verbose #echo on


# this also checks command line params - but shifting above will remove. This is ok...
source $CSAP_FOLDER/bin/csap-environment.sh

function install_if_needed() { 
	packageName="$1"
	
	if $(is_need_package $packageName) ; then
		run_using_root yum -y install $packageName
	fi ; 
}


# print_line "Validating Jmeter OS Dependencies"
install_if_needed libXrender
install_if_needed libXtst
install_if_needed libXi


# do not kill either this process or the grep command
checkForRunningJmeters=$(ps -ef | grep csapVerify=$csapName | grep -v -e grep -e $0  | wc -l)

#print_line "Checking if jmeter is already running: $checkForRunningJmeters"


if [ "$checkForRunningJmeters" != "0" ] ; then
	#parentPid=`ps -ef | grep csapVerify=$csapName  | grep -v -e grep -e $0 | awk '{ print $2 }'`
	
	# In case process has spawned any children, they will be killed as well
	# searchPidsWithEadded=`echo $parentPid | sed 's/ / -e /g'`
	# svcPid=`ps -ef | grep -e $searchPidsWithEadded  | grep -v -e grep -e $0 | awk '{ print $2 }'`

#	svcPid=$(ps -ef | grep --extended-regexp "JMeter.*$csapName"  | grep -v -e grep -e $0 | awk '{ print $2 }')
#	print_line "found an already running instance on pid: $svcPid , killing it"
#	kill -9 $svcPid
	
	svcPid=$(ps -ef | grep --extended-regexp "$csapName-load-test.sh"  | grep -v -e grep -e $0 | awk '{ print $2 }')
	print_line "found an already running instance on pid: $svcPid , killing it"
	kill -9 $svcPid
	

	svcPid=$(ps -ef | grep --extended-regexp "JMeter.*$csapName"  | grep -v -e grep -e $0 | awk '{ print $2 }')
	print_line "found an already running instance on pid: $svcPid , killing it"
	kill -9 $svcPid
	
	print_separator "Performance Test Stopped"
	
	exit ;
fi

killOnly=${killOnly:-false} ;
if $killOnly ; then
	print_two_columns "exiting" "killOnly flag was set" ;
	exit;
fi

testFolder=${testFolder:-$csapWorkingDir/jmeter-test-files} ; 
if [ ! -d "$testFolder" ]; then
	print_error "Exiting: unable to locate testFolder: '$testFolder'"
	exit ;
fi
print_two_columns "jmeter folder" "'$testFolder'"

export time_in_minutes=${time_in_minutes:-3} ;
export time_in_seconds=$(( time_in_minutes * 60)) ;
print_two_columns "test duration" "'$time_in_minutes' minutes"


export jmeterLogFolder="$csapLogDir/performance";
logOutput="$jmeterLogFolder/mavenVerify.txt"
backup_file $logOutput
if [ ! -d $jmeterLogFolder ] ; then
	print_line "Creating $jmeterLogFolder" 
	mkdir -p $jmeterLogFolder ;
fi ;

print_two_columns "test start" "maven verify will be run in: '$testFolder'"
print_two_columns "logs" "logs will be stored in: '$logOutput'"



if [ ! -f $HOME/hc.parameters ] ; then 
	
	print_separator "Creating $HOME/hc.parameters, add <hc.parameters.file>/opt/csapUser/hc.parameters</hc.parameters.file>"
	echo -e 'http.connection.stalecheck$Boolean=true\n' > $HOME/hc.parameters
	
fi ;


export MAVEN_OPTS="-Djava.awt.headless=true -Xms2048m -Xmx2048m"
print_two_columns "MAVEN_OPTS" "$MAVEN_OPTS"


if [ -f "$testFolder/pom.xml" ] ; then

	print_line "switching to folder:  '$testFolder'"
	cd $testFolder 
	
	if [ -e "$csapDefinitionResources/settings.xml" ] ; then
		# nohup mvn -B -s $csapDefinitionResources/settings.xml -DcsapVerify=$csapName verify &> $logOutput &
		resultsFromPlugin="../jmeter/reports/test-definition"
		resultsFolder="../jmeter/reports/"$(date '+%B-%d-%A-%H-%M') ;
		
		
		print_two_columns "resultsFromPlugin" "$resultsFromPlugin"
		print_two_columns "resultsFolder" "$resultsFolder (plugin results relocation at end of run)"
		
		#print_line "Running in background:  nohup mvn verify using $csapDefinitionResources/settings.xml"
		#print_line "results from jmeter plugin will be moved from $resultsFromPlugin to $resultsFolder"
		
		print_separator "launching load test in background (nohup mvn verify ...)"
		
		loadTestScript="$CSAP_FOLDER/saved/scripts-run/$csapName-load-test.sh"
		if test -f $loadTestScript ; then
			rm --force --verbose $loadTestScript ;
		fi ; 
		append_file "#!/bin/bash" $loadTestScript false
		append_line "source $CSAP_FOLDER/bin/csap-environment.sh"
		append_line "mvn -B -s $csapDefinitionResources/settings.xml -DcsapVerify=$csapName verify"
		append_line "mv --verbose $resultsFromPlugin $resultsFolder"
		
		chmod 755 $loadTestScript
		launch_background "$loadTestScript" "" "$logOutput"
		
		# nohup sh -c "mvn -B -s $csapDefinitionResources/settings.xml -DcsapVerify=$csapName verify &> $logOutput; mv --verbose $resultsFromPlugin $resultsFolder &>>  $logOutput" &
	else
		print_line "Warning: $csapDefinitionResources/settings.xml not found - best practice is to include one in capability/propertyOverride folder"
		print_line "Running in background:  nohup mvn $CSAP_FOLDER/bin/settings.xml -DcsapVerify=$csapName verify using default settings.xml"
		nohup mvn -B -s $CSAP_FOLDER/bin/settings.xml -DcsapVerify=$csapName verify  &> $logOutput &
	fi ;
else 
	print_line "Warning: could not find folder: \"$testFolder/pom.xml\" "
	print_line mvn verify not run
	exit ;
fi

add_note start
	
add_note "Load test is running in background, use csap service portal logs for '$csapName'"
add_note "1. when run is completed, you can view the jmeter report"
add_note "2. If you did not update the test-settings.txt file with correct params (user,pass,...), then you will see lots of errors"
add_note "3. You can modify run duration using time_in_minutes environment variable"
add_note "4. Restarting test will abort test in progress, with no reports generated"

add_note end

print_line "$add_note_contents" ;
	




