#!/bin/sh
#
#
#


function checkOutRepos() {
	
	local repositorys="$1" ;
	local gitDestination="$2" ;
	
	local publishLocation=${3:-skip} ;
	
	print_section "checkOutRepos to folder: $gitDestination"
	
	if test -e $gitDestination ; then
	
#		prompt_to_continue "delete gitDestination '$gitDestination'"
		print_two_columns "Deleting" "$gitDestination"
		rm --recursive --force $gitDestination
		
	fi ;
	
	print_two_columns "creating" "$(mkdir --parents --verbose $gitDestination)";
	 
	cd $gitDestination 
	
	print_if_debug "repositorys: $repositorys"
	
	for repository in $repositorys ; do
	
		print_line "";
		print_two_columns "repository" "$repository"
		git clone --depth 1 $repository
		
		if [[ $publishLocation != "skip" ]] ; then
		
			local projFolder=$(basename $repository);
			local gitFolder="$projFolder/.git" ;
			print_two_columns "removing" "$gitFolder"
			rm --recursive --force $gitFolder
			
			if [[ "$projFolder" == oss* ]]; then
			
				local newName=${projFolder:4} ;
				print_two_columns "newName" "$newName (was $projFolder)"
				mv $projFolder $newName.legacy
				projFolder=$newName
			fi ;
			
			
			
			local gitHubLocation="$publishLocation/$projFolder.git";
			
			print_two_columns "cloning" "$gitHubLocation"
			git clone $gitHubLocation
			local returnCode=$?
			
			if (( $returnCode == 0 )) ;  then
			
				cp --recursive --force --no-target-directory --preserve=mode,ownership,timestamps $projFolder.legacy $projFolder
				
				cd $projFolder ;
				
				if ! test -d .git ; then
				
					print_two_columns "init" "running git init"
				
					git init
					git add .
					git commit -m "first commit"
					git branch -M master
#					git remote add origin $gitHubLocation
					
				else
					
					NOW=$(date +"%h-%d-%I-%M-%S") ;
					# testing only
#					echo "test" >> test-$NOW
#					rm --recursive --force test*
					
					git add --all
					
					print_two_columns "created" "$test-$NOW"
					git commit -m "csap-master-merge $NOW"
				fi ;
				
				print_two_columns "pushing" "$gitHubLocation"
				git push -u origin master
				
			fi
			
			
#			touch readme.md
#			cat "#demo" >> readme.md
#			git init
#			git add .
#			git commit -m "first commit"
#			git branch -M master
#			git remote add origin $gitHubLocation
#			
#			print_two_columns "pushing" "$gitHubLocation"
#			git push -u origin master

			cd ..
		
		fi ;
		
	done ;
	
}

function performBuild() {
	
	local buildFolders="$1" ;
	local m2="$2" ;
	local mavenCommand="$3" ;
	
	print_if_debug "runBuilds  folder: $buildFolder" ;
	
	local mavenSettings="$m2/settings.xml" ;
	if [ ! -e "$mavenSettings" ] ; then
		prompt_to_continue "Warning: $mavenSettings not found"
	fi
	
	for buildFolder in $buildFolders ; do

		cd $buildFolder ;
		print_section "Building $buildFolder" ;
		
		print_two_columns "mvn" "--batch-mode --settings $mavenSettings" 
		print_two_columns "command" "$mavenCommand" 
		print_two_columns "MAVEN_OPTS" "$MAVEN_OPTS" 
		
		print_separator "maven output start"
		mvn --batch-mode --settings $mavenSettings $mavenCommand 2>&1 | sed 's/^/  /'
		
		buildReturnCode="$?" ;
		if [ $buildReturnCode != "0" ] ; then
			print_line "Found Error RC from build: $buildReturnCode"
			echo __ERROR: Maven build exited with none 0 return code
			exit 99 ;
		fi ;
		
		print_separator "maven output end"
	
	done ;
	
}
