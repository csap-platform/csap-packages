#!/bin/bash

sourceCodeUrl=${sourceCodeUrl:-http://csap-dev01.lab.sensus.net:8080} ;

# +DisableReuse gets better scaling and dynamic connection management
modJkParameters=${modJkParameters:-+ForwardKeySize +ForwardURICompat -ForwardDirectories} ;
isToolServer=${configureAsToolServer:-false} ;
httpdDocFolder=${httpdDocFolder:-$HOME/csap-web-server} ;
createPort80Tunnel=${createPort80Tunnel:-false}


#
#  NOTE WHEN UPDATING: version is ALSO in csap-package-httpd-uber/pom.xml for host installation
#
#binaryVersion=${binaryVersion:-2.4.29.2} ;


binaryVersion=${binaryVersion:-2.4.48.1} ;

# handle wrapped references
httpdDocFolder=$(eval echo $httpdDocFolder) ; 

print_section "CSAP Httpd Package"

print_two_columns "binaryVersion" "$binaryVersion"
print_two_columns "createPort80Tunnel" "$createPort80Tunnel"
print_two_columns "httpdDocFolder" "$httpdDocFolder"
print_two_columns "isToolServer" "$isToolServer"
print_two_columns "modJkParameters" "$modJkParameters"
print_two_columns "sourceCodeUrl" "$sourceCodeUrl"

function getSourcePackage() {
	
	fileName="$1"
	localFile="$httpdDocFolder/$fileName"
	
	# print_with_head "Downloading: '$fileName'  to $(pwd)"
		
	if [ -f $localFile ] ; then 
	
		print_line "getSourcePackage() Using local file: $(cp --verbose $localFile .)"
		
	else 
		packageSource="http://$toolsServer/$fileName"
		
		print_line "Getting $packageSource"
		wget -nv $packageSource
		
		if [ $? != 0 ] ; then 
			print_line "error: failed to download: $packageSource"; 
			
			localPackage="$HOME/opensource/httpd.zip"
			print_line "checking $localPackage"
			if [ -e $localPackage ] ; then
				unzip -j -n $localPackage -d . 
			else 
				exit;
			fi ; 
		fi ;
	fi ;
	
}

function getSourcePackages() {
	
	
	getSourcePackage httpd/apr-1.5.2.zip
	getSourcePackage httpd/apr-util-1.5.2.zip
	getSourcePackage httpd/httpd-2.4.48.tar.gz #download httpd/httpd-2.4.23.zip
	getSourcePackage httpd/pcre-8.37.zip
	getSourcePackage httpd/tomcat-connectors-1.2.48-src.tar.gz
	

}

function extractFiles() {

	local message="$1"
	local fileName="$2"
	print_with_big_head "$message: extracting $fileName to $(pwd)"
	tar --extract --gzip --file=$fileName
	local theReturnCode=$? ;
	
	if [ $? != 0 ] ; then
		print_with_head "Extraction failed"
		exit ;
	fi ;
	
	

}

function buildApacheBinary() {


	export APACHE_HOME=$csapWorkingDir
	
	print_with_head "building web server: apacheBinary.zip"
	print_two_columns "build in" "$(pwd)"
	print_two_columns "install in" "$APACHE_HOME"

	getSourcePackages
	
	#ls -l $csapPackageFolder
	if [ ! -e "/usr/include/zlib.h" ] ; then
		print_line "ERROR: Missing compression package. Use yum -y install zlib-devel"
		exit ;
	fi
	
	# echo  == Getting binary deployment - use maven as it will act as a caching proxy server
	# add any other deploy time hooks


	
	if [ -e $APACHE_HOME/bin/apachectl ] ; then 
		print_line "\n\n\t running: '$APACHE_HOME/bin/apachectl'"
		$APACHE_HOME/bin/apachectl stop ;
	else
		print_line "\n\n\t Skipping stop: Did not find: '$APACHE_HOME/bin/apachectl'"
	fi
	
	print_line "removing previous csapWorkingDir as it is the target for build: '$csapWorkingDir'"
	rm -rf $csapWorkingDir
	
	print_line "Setting up WebServer in $APACHE_HOME"
	
	extractFiles "1 of 5" httpd*.gz
	chmod -R 755 httpd*
	
	print_line "Switching to httpd folder for remaining extracts" ;
	cd httpd*
	
	print_line "2nd Apache HOOK: Need to strip off existing apache from path because configure will attempt to us it"
	export PATH=${PATH/httpd/dummyForBuild}
	
	#
	print_line  "Getting source for remote packages. Note http://httpd.apache.org/docs/current/install.html"
	cd srclib
	
	extractFiles "2 of 5" ../../pcre*.zip
	#tar -xvzf ../../pcre*.zip
	
	cd pcre*
	print_line "running configure in '$(pwd)'\n\n"
	./configure --prefix=$APACHE_HOME
	print_line "running make in '$(pwd)'\n\n"
	make install
	cd ..
	
	extractFiles "3 of 5" ../../apr-1*.zip
	#tar -xvzf ../../apr-1*.zip
	ls
	mv apr-1.5.2/ apr
	
	
	extractFiles "4 of 5" ../../apr-util*.zip
	#tar -xvzf ../../apr-util*.zip
	ls
	mv apr-util-1.5.2/ apr-util

	cd ..
	
	# http://httpd.apache.org/docs/current/misc/perf-tuning.html 
	# ref. http://httpd.apache.org/docs/2.4/programs/configure.html 
	# most picks up rewrite, all picks up proxy --enable-modules=most --enable-MODULE=static -enable-proxy  
	# --with-mpm=worker is no longer the default, switching to event
	# set COMPILE_OPTIONS to --disable-ssl
	
	print_line "COMPILE_OPTIONS has ssl disable" 
	./configure --prefix=$APACHE_HOME --with-pcre=$APACHE_HOME --enable-mods-static=all  --with-included-apr --disable-ssl
	
	
	print_line "\n\n running make httpd in $(pwd)\n\n"
	make 
	print_line "\n\n running make install httpd in $(pwd)\n\n"
	make install
	cd $CSAP_FOLDER/temp
	# rm -rf http*
	
	extractFiles "5 of 5" tomcat-connectors*.gz
	#tar -xvzf tomcat-connectors*.zip
	
	chmod -R 755  tomcat*src
	cd  tomcat*src/native
	
	print_line "\n\n running configure in $(pwd)\n\n"
	 ./configure --with-apxs=$APACHE_HOME/bin/apxs
	 cd apache-2.0
	
	print_line "\n\n running make in $(pwd)\n\n"
	make
	cp mod_jk.so $APACHE_HOME/modules
	cd $CSAP_FOLDER/temp
	 # rm -rf tom*
	 
	print_with_head "Apache compile completed, creating apacheBinary.zip"
	cd $csapWorkingDir ; # need to zip in a relative folder
	
	print_line "zipping binary in $csapWorkingDir"
	zip -q -r apacheBinary *
	
}

function checkInstalled() { 
	packageName="$1"
	#rpm -q $packageName
	if is_need_package $packageName ; then 
		print_line "error: $packageName not found, install using yum -y install" ; 
		exit; 
	fi   
}


function api_package_build() {
	
	print_with_big_head "api_package_build"
	
	if [[ "$mavenBuildCommand" != *package* ]] ; then
		print_line "Skipping source build" ;
		return ;
	fi ;
	
	print_line "Current directory is $(pwd), agent has built wrapper to $csapPackageFolder/$csapName.zip"
	#print_line "httpd source code build will be bypassed if '$HOME/opensource/httpd.zip' exists"
	if [ -r "$HOME/opensource/apacheBinary.zip" ] ; then 
	
		print_with_head "NOTE: Source build skipped, copying $HOME/opensource/apacheBinary.zip to '$csapWorkingDir'"
		mkdir --parents --verbose $csapWorkingDir
		cp --force --verbose $HOME/opensource/apacheBinary.zip $csapWorkingDir
		#cp $HOME/opensource/apacheBinary.zip .
		#unzip  -fj $HOME/opensource/httpd.zip apacheBinary.zip -d .
	else
		osPackages="gcc gcc-c++ make zlib-devel zip unzip"
		print_with_head "Verifying required packages installed on host: '$osPackages'"
		
		for package in $osPackages ; do
			checkInstalled $package
		done ;
		
		buildApacheBinary 
	fi ;
	
	\rm --recursive --force $csapPackageDependencies
	mkdir --parents --verbose $csapPackageDependencies
	cp --force --verbose $csapWorkingDir/apacheBinary.zip $csapPackageDependencies
	
	print_two_columns "mavenBuildCommand" "$mavenBuildCommand"
	
	if [[ "$mavenBuildCommand" == *deploy* ]] ; then
		deploy_binary
	fi ;
	
		
	print_line "\n\n Deleting $csapWorkingDir"
	rm --recursive --force $csapWorkingDir
	
	print_with_head "\n\n api_package_build() completed"
	
}

function update_repo_variables() {
	REPO_ID="csap-release-repo"
	REPO_URL="$svcRepo"
	
	
	if [[ "$binaryVersion" == *SNAPSHOT* ]] ; then
		REPO_ID="csap-snapshot-repo" ;
		REPO_URL="$(dirname $svcRepo)/csap-snapshots/" ;
	fi 
	
	

	ARTIFACT_ID="apacheBinary"
	FILE=apacheBinary.zip
	GROUP_ID="bin"
	TYPE="zip"
	
	print_two_columns "FILE" "$FILE"
	print_two_columns "Version" "$binaryVersion"
	print_two_columns "REPO_ID" "$REPO_ID"
	print_two_columns "REPO_URL" "$REPO_URL"
}

function deploy_binary() {

	print_with_head "Deploying apacheBinary to repository using maven: '$(pwd)'"
	
	update_repo_variables
	
	local deployCommand="deploy:deploy-file -DgroupId=$GROUP_ID -DartifactId=$ARTIFACT_ID -Dversion=$binaryVersion -Dpackaging=$TYPE -Dfile=$FILE"
	deployCommand="$deployCommand -DrepositoryId=$REPO_ID -Durl=$REPO_URL"
	
	csap_mvn $deployCommand
}

function api_package_get() {


	print_with_head "api_package_get(): csapBuildVersion: '$csapBuildVersion'"

	if [[ "$csapBuildVersion" == "" ]] ; then
		print_line "api_package_get() skipping binary retrieval, using binary just built"
		return ;
	fi ;
	
	print_line "api_package_get(): removing previous files in $csapPackageDependencies"
	update_repo_variables
	
	\rm --recursive --force $csapPackageDependencies
	
	mkdir -p $csapPackageDependencies
	cd $csapPackageDependencies
	
	csap_mvn dependency:copy -Dtransitive=false -Dartifact=bin:apacheBinary:$binaryVersion:zip -DoutputDirectory=$(pwd)
	
}

function install_apache_binary() {
	
	local apacheBinary=$csapPackageDependencies/apacheBinary*.zip ;
	
	print_with_head "install_apache_binary(): extracting '$apacheBinary' to '$(pwd)'"
	
	if $( ! test -e $apacheBinary ) ; then 	
		print_line "Error: did not find $csapPackageDependencies/apacheBinary.zip  in $csapPackageDependencies "
		exit;	
	fi ;
	
	cp   --force --verbose $apacheBinary .
	unzip -qq -o $apacheBinary
	
}

function api_service_kill() {
	
	print_with_head "KILL: Current directory is $(pwd)"
	export APACHE_HOME=$csapWorkingDir
	
	api_service_stop
	
}

function clearHttpdSemaphoresFromSharedMemory() {
	
	print_with_head "clearHttpdSemaphoresFromSharedMemory is being invoked incase semaphores are still present"

	
	# rh 6 uses non root users, but redhat 5 still uses root to own.
	for semid in `ipcs -s | grep -v -e - -e key  -e "^$" | cut -f2 -d" "`; do ipcrm -s $semid; done
	for semid in `ipcs -m | grep -v -e - -e key  -e "^$" | cut -f2 -d" "`; do ipcrm -m $semid; done
	
	#rm -rf $CSAP_FOLDER/bin/csap-deploy-as-root.sh
		
	# 
	# ssadmin user has sudo root on file: $CSAP_FOLDER/bin/csap-deploy-as-root.sh
	# So content is put in there for execution as root
	#
	##echo 'for semid in `ipcs -s | grep -v -e - -e key  -e "^$" | cut -f2 -d" "`; do ipcrm -s $semid; done' >>  $CSAP_FOLDER/bin/csap-deploy-as-root.sh
	##echo 'for semid in `ipcs -m | grep -v -e - -e key  -e "^$" | cut -f2 -d" "`; do ipcrm -m $semid; done' >>  $CSAP_FOLDER/bin/csap-deploy-as-root.sh
	
	##chmod 755 $CSAP_FOLDER/bin/csap-deploy-as-root.sh
	##	sudo $CSAP_FOLDER/bin/csap-deploy-as-root.sh $csapWorkingDir/scripts
		
	
	print_line "ipcs output, note that httpd start up will fail if ipcs is still showing semaphores"
	ipcs -a
	
	numLeft=$(ipcs | grep -v -e - -e key -e root -e "^$" | wc -l)
	
	if [ $numLeft != "0" ] ; then
		print_line "Error : httpd is not ok with semaphores on system. Use ipcs to list and ipcsrm to delete"
		sleep 10 ; # give console a chance to view
	else 
		print_line "It appears all semaphores have been deleted";
	fi
}

function api_service_stop() {
	print_with_head "api_service_stop()"
	
	export APACHE_HOME=$csapWorkingDir
	
	print_line trying a graceful shutdown first: $APACHE_HOME/bin/apachectl stop 
	$APACHE_HOME/bin/apachectl stop
	
	checkForPort80Routing false ;
	
	
	sleep 5

	clearHttpdSemaphoresFromSharedMemory
	
	print_line completed httpd stop   ;
}

function api_service_start() {
	
	print_with_head "api_service_start()"
	
	cd $csapWorkingDir ;
	
	export APACHE_HOME=$csapWorkingDir
	APACHE_HOME=$csapWorkingDir
	
	clearHttpdSemaphoresFromSharedMemory
	
	print_line "Starting Apache httpd in $APACHE_HOME"

	
	
	if [ ! -e  "$csapWorkingDir/bin" ] ; then
	
		install_apache_binary
		
		if [[ "$isToolServer" == "true" ]] ; then 
			configureToolsHttpd
		else 
			configureStandardHttpd
		fi ;

		configureLogging
		createVersion
		
	else
		
		print_line "Found bin, skipping extraction of httpd config files"
		
	fi ;
	
	if [ ! -e "$CSAP_FOLDER/httpdConf/csspJkMount.conf" ] ; then
		print_error " do a Tools/Generate Http loadbalance"
		exit ;
	fi ;
	

	if [ ! -e "$CSAP_FOLDER/httpdConf/csspCustomRewrite.conf" ] ; then
		print_line "Generating an empty $CSAP_FOLDER/httpdConf/csspCustomRewrite.conf"
		touch $CSAP_FOLDER/httpdConf/csspCustomRewrite.conf
	fi ;
	$APACHE_HOME/bin/apachectl restart
	
	
	
	checkForPort80Routing $createPort80Tunnel
	
	
	print_with_head "completed httpd startup"
	
}

function checkForPort80Routing() {

	local createRoute=${1}
	
	run_using_root "export CSAP_FOLDER=$CSAP_FOLDER; $csapWorkingDir/scripts/routing.sh $csapPrimaryPort 80 $createRoute"

}

function configureToolsHttpd() {
		
	print_with_head "Running configureToolsHttpd - special for csap tools server in $(pwd)"
	
	print_line "Install $csapWorkingDir/scripts/toolsConfig/httpdTemplate.conf"
	
	cp $csapWorkingDir/scripts/toolsConfig/httpdTemplate.conf $APACHE_HOME/conf/httpd.conf

	updateHttpdTemplate
		
	if [ ! -d $httpdDocFolder ] ; then 
		print_line "Creating folder: '$httpdDocFolder'"
		run_using_root "mkdir --parents $httpdDocFolder; chown -R $USER $httpdDocFolder"
	fi
		
	print_line "copying 'scripts/htdocs and scripts/toolsConfig/htdocs' to '$httpdDocFolder'"
	cp --force --recursive scripts/htdocs/* $httpdDocFolder
	cp --force --recursive scripts/toolsConfig/htdocs/* $httpdDocFolder

	# Update the host name in the index page.
	sed --in-place "s=csap-web01=$HOSTNAME=g" $httpdDocFolder/web.html
	\rm -rf $httpdDocFolder/web ;
	ln -s $httpdDocFolder/web.html $httpdDocFolder/web
	
	sed --in-place "s=_HTTPD_DOC_ROOT_=$httpdDocFolder=g" $APACHE_HOME/conf/httpd.conf
}


function configureStandardHttpd() {
		
	print_with_head "Running configureStandardHttpd"
	print_line Install $csapWorkingDir/scripts/httpdTemplate.conf
 	cp $csapWorkingDir/scripts/httpdTemplate.conf $APACHE_HOME/conf/httpd.conf

	updateHttpdTemplate
		
	print_line copying scripts/htdocs/* to $APACHE_HOME/htdocs
	cp --force --recursive scripts/htdocs/* $APACHE_HOME/htdocs	
}

function updateHttpdTemplate() {
	
	sed -i "s/_MOD_JK_CONFIG_/$modJkParameters/g" $APACHE_HOME/conf/httpd.conf
	
	sed -i "s/_HTTPDPORT_/$csapHttpPort/g" $APACHE_HOME/conf/httpd.conf
	
	# interesting using = as the sed delim in order to insert paths with / in them
	
	
	sed -i "s=_APACHEHOME_=$APACHE_HOME=g" $APACHE_HOME/conf/httpd.conf				
	sed -i "s=_REWRITE_=$CSAP_FOLDER/httpdConf/csspRewrite.conf=g" $APACHE_HOME/conf/httpd.conf
	sed -i "s=_CUSTOMREWRITE_=$CSAP_FOLDER/httpdConf/csspCustomRewrite.conf=g" $APACHE_HOME/conf/httpd.conf
	sed -i "s=_PROXY_=$CSAP_FOLDER/httpdConf/proxy.conf=g" $APACHE_HOME/conf/httpd.conf
		
	
	print_line Configuring $APACHE_HOME/conf/httpd.conf  to use $CSAP_FOLDER/httpdConf/worker.properties, $CSAP_FOLDER/httpdConf/csspJkMount.conf
	sed -i "s=_WORKER_=$CSAP_FOLDER/httpdConf/worker.properties=g" $APACHE_HOME/conf/httpd.conf
	sed -i "s=_JKMOUNT_=$CSAP_FOLDER/httpdConf/csspJkMount.conf=g" $APACHE_HOME/conf/httpd.conf	
	
}

function createVersion() {
	
	print_with_head "Creating version"
	
	packageVersion=$(ls $csapWorkingDir/version | head -n 1)
	
	print_line "Appending apachectl version to package version"
	
	apacheFullVersion=$(apachectl -v|grep version |awk '{print $3};')
	apacheVersion=$(basename $apacheFullVersion)
	
	myVersion="$apacheVersion--$packageVersion"
	
	print_line "Renaming version folder: $csapWorkingDir/version/$packageVersion to $myVersion"
	
	\mv -v "$csapWorkingDir/version/$packageVersion" "$csapWorkingDir/version/$myVersion" 

	
}

function configureLogging() {
	print_with_head "creating $csapWorkingDir/logs"
	mkdir -p $csapWorkingDir/logs

	
	print_line creating $csapWorkingDir/logs/logRotate.config
	
	echo "#created by httpdWrapper" > $csapWorkingDir/logs/logRotate.config
	echo "$csapWorkingDir/logs/access.log {" >> $csapWorkingDir/logs/logRotate.config
	echo "copytruncate" >> $csapWorkingDir/logs/logRotate.config
	echo "weekly" >> $csapWorkingDir/logs/logRotate.config
	echo "rotate 3" >> $csapWorkingDir/logs/logRotate.config
	echo "compress" >> $csapWorkingDir/logs/logRotate.config
	echo "missingok" >> $csapWorkingDir/logs/logRotate.config
	echo "size 10M" >> $csapWorkingDir/logs/logRotate.config
	echo "}" >> $csapWorkingDir/logs/logRotate.config
	echo "" >> $csapWorkingDir/logs/logRotate.config
	
	
	echo "$csapWorkingDir/logs/error_log {" >> $csapWorkingDir/logs/logRotate.config
	echo "copytruncate" >> $csapWorkingDir/logs/logRotate.config
	echo "weekly" >> $csapWorkingDir/logs/logRotate.config
	echo "rotate 3" >> $csapWorkingDir/logs/logRotate.config
	echo "compress" >> $csapWorkingDir/logs/logRotate.config
	echo "missingok" >> $csapWorkingDir/logs/logRotate.config
	echo "size 10M" >> $csapWorkingDir/logs/logRotate.config
	echo "}" >> $csapWorkingDir/logs/logRotate.config
	echo "" >> $csapWorkingDir/logs/logRotate.config
	
	echo "$csapWorkingDir/logs/mod_jk.log {" >> $csapWorkingDir/logs/logRotate.config
	echo "copytruncate" >> $csapWorkingDir/logs/logRotate.config
	echo "daily" >> $csapWorkingDir/logs/logRotate.config
	echo "rotate 5" >> $csapWorkingDir/logs/logRotate.config
	echo "compress" >> $csapWorkingDir/logs/logRotate.config
	echo "missingok" >> $csapWorkingDir/logs/logRotate.config
	# This will run hourly rotates. 
	echo "size 5M" >> $csapWorkingDir/logs/logRotate.config
	echo "}" >> $csapWorkingDir/logs/logRotate.config
	echo "" >> $csapWorkingDir/logs/logRotate.config	
}
