#!/bin/bash


scriptDir=$(pwd)
scriptName=$(basename $0)
echo "Working Directory: '$(pwd)'"

releaseFolder=${releaseFolder:-/mnt/CSAP_DEV01_NFS/csap-web-server} ;

buildLocation="/mnt/c/Users/peter.nightingale/csap-gits" ;
m2="/mnt/c/Users/peter.nightingale/.m2" ;



publishLocation="git@github.com:csap-platform" ;
#publishLocation="skip" ;


# gitFolders=$( echo git@bitbucket.org:xyleminc/oss-sample-project ) ;	
 gitFolders=$(echo \
	git@bitbucket.org:xyleminc/oss-csap-bin \
	git@bitbucket.org:xyleminc/oss-csap-build \
	git@bitbucket.org:xyleminc/oss-csap-core \
	git@bitbucket.org:xyleminc/oss-csap-event-services \
	git@bitbucket.org:xyleminc/oss-csap-images \
	git@bitbucket.org:xyleminc/oss-csap-installer \
	git@bitbucket.org:xyleminc/oss-csap-java \
	git@bitbucket.org:xyleminc/oss-csap-packages \
	git@bitbucket.org:xyleminc/oss-csap-starter \
	git@bitbucket.org:xyleminc/oss-sample-project )

buildFolders="$buildLocation/oss-sample-project";

if [ -e installer/csap-environment.sh ] ; then
	source installer/csap-environment.sh

elif [ -e ../environment/csap-environment.sh ] ; then

	cd ..
	scriptDir=$(pwd) ;
	
	echo -e "\n\nDesktop development using windows subsystem for linux: \n\t '$scriptDir'"
	ENV_FUNCTIONS=$scriptDir/environment/functions ;
	source $scriptDir/environment/csap-environment.sh ;
	
else

	echo "Desktop development"
	source $scriptDir/platform-bin/csap-environment.sh
	
fi


#debug=true;
print_debug_command \
	"Environment variables" \
	"$(env)"



# change timer to 300 seconds or more
release="latest"; # or 2.0.0, etc

includePackages="no" ; # regex: use .* for all, or csap 
includeMavenRepo="no" ; # set to yes to include maven Repo
targetHost="do-not-copy"


buildFunctions="$scriptDir/installer/build-csap-functions.sh" ;


print_two_columns "loading" "$buildFunctions"
source $buildFunctions ;



checkOutRepos "$gitFolders" $buildLocation $publishLocation

# performBuild "$buildFolders" "$m2" "-Dmaven.repo.local=$m2/repository clean package install" 
