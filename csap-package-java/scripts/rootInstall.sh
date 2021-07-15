#!/bin/bash

function command_settings() {

	helperFunctions=${1:-/opt/csap/csap-platform/bin/csap-environment.sh} ;
	source $helperFunctions;
	
}

command_settings $* ;


#for testing - blow away existing folder. Do not do this if Agent is using it
testMode=false;
if [ "$(hostname --short)" == "centos1" ] ; then testMode=true ; fi ;



function install_java () {
	
	local javaFolderName="openjdk-$shortVersion"
	
	print_separator "user: '$USER'" ;
	print_two_columns "source" "$csapWorkingDir" ;
	print_two_columns "javaFolderName" "$javaFolderName" ;
	
	
	print_two_columns "case matching" "disabling  in expressions that use [[ ]]: shopt -s nocasematch"
	shopt -s nocasematch
	
	# if installing as java - it becomes the default JAVA_HOME
#	isDefaultJava=$(if [[ `basename "$csapWorkingDir"` = "csap-package-java" ]]; then echo true; else echo false; fi) ;
	
		
	if [ "$USER" == "root" ] ; then
		mkdir --parents --verbose /opt/java
		cd /opt/java ;
		installPath="/opt/java/$javaFolderName"
		
		# delete locations
		delete_all_in_file "JAVA11_HOME" /etc/bashrc ;
		#sed -i '/JAVA11_HOME/d' /etc/bashrc
		#echo  export JAVA11_HOME=$installPath >> /etc/bashrc
		append_file "export JAVA11_HOME=$installPath" /etc/bashrc true
		
#		if $isDefaultJava ; then 
			
		#print_info "default java" "Updating JAVA_HOME in /etc/bashrc"
		#sed -i '/JAVA_HOME/d' /etc/bashrc
		delete_all_in_file "JAVA_HOME"  ;
		append_line  export JAVA_HOME=$installPath
		append_line  export PATH=\$JAVA_HOME/bin:\$PATH
#		echo  export JAVA_HOME=$installPath >> /etc/bashrc
#		echo  export PATH=\$JAVA_HOME/bin:\$PATH >> /etc/bashrc
		
		print_if_debug "$(tail -10 /etc/bashrc 2>&1)"
			
			
#		else
#			
#			print_info "Not default" "Installing as non default JDK"
#			
#		fi ;
		
	else
		
		source $HOME/.csapEnvironment
		installPath="$CSAP_FOLDER/../java/$javaFolderName" 
		if [ "$INSTALL_DIR" != "" ] ; then 
			print_with_head "using custom location $INSTALL_DIR"
			mkdir --parents --verbose $INSTALL_DIR ;
			
			cd $INSTALL_DIR ;
			installPath="$INSTALL_DIR/$javaFolderName" 
		
		else 
			echo "using default location $CSAP_FOLDER/../java"
			cd $CSAP_FOLDER/../java ;
		fi
		
		print_with_head "adding link to: $(pwd) from: $csapWorkingDir/JAVA_HOME"
		ln -s $(pwd) $csapWorkingDir/JAVA_HOME
		
		JAVA11_HOME=$installPath
		
		sed -i '/JAVA11_HOME/d' $HOME/.csapEnvironment
		echo  "export JAVA11_HOME=$installPath" >> $HOME/.csapEnvironment
		
		if $isDefaultJava ; then 
			print_with_head "service name is java, JVM will become system default by updating JAVA_HOME"
			sed -i '/JAVA_HOME/d' $HOME/.csapEnvironment
			echo  export JAVA_HOME=$installPath >> $HOME/.csapEnvironment
			echo "contents of $HOME/.csapEnvironment":
			tail -10 $HOME/.csapEnvironment
			
		else
			print_info "Installing as non default JDK"
		fi ;
		
		# PATH is set in CSAP_FOLDER/bin/admin.bashrc. We just need to update java_home
		#echo  export PATH=\$JAVA_HOME/bin:\$PATH >> $HOME/.csapEnvironment
		source $HOME/.bashrc
	fi ;
	
	if [ -d  $installPath ] ; then
		
		if $testMode ; then 
			print_with_head "testMode set, deleting $installPath"
			\rm -rf $installPath ;
			
		else
			print_with_head "java already installed at '$installPath', skipping extraction"
			exit ;
		fi ;
		
	fi
	
	
	\rm --recursive --force temp
	mkdir --parents --verbose temp
	cd temp
	
	print_two_columns "extracting"  "$csapPackageDependencies/*jdk*.tar.gz"
	print_two_columns "destination"  "$(pwd)"
	tar --preserve-permissions --extract --gzip --file $csapPackageDependencies/*jdk*.tar.gz
	
	print_two_columns "moving" "$installPath" ;
	mv --force * $installPath
	
	print_two_columns "permissions" "755" ;
	chmod --recursive 755 $installPath 
	
	
	source $HOME/.bashrc
	
	print_two_columns "JAVA11_HOME" "$JAVA11_HOME"
	 
}


install_java ;


