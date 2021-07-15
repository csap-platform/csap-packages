#!/bin/bash

info="https://access.redhat.com/articles/2317361" ;
scriptName="docker-commands-rh.sh"

function command_settings() {
	
	helperFunctions=${1:-/opt/csapUser/staging/bin/csap-shell-utilities.sh} ;
	source $helperFunctions;
	command=$2
	
	dockerStorage=${dockerStorage:/opt/csapUser/dockerStorage}
	allowRemote=${allowRemote}
	dockerPackage=${dockerPackage:-docker-latest}
	dockerPort=${csapPrimaryPort:-4243}
	
	print_with_head "$scriptName: '$command',\t dockerStorage: '$dockerStorage',\t  allowRemote: '$allowRemote'" \
		"\n\t dockerPackage: '$dockerPackage',\t dockerRepo: '$dockerRepo'" \
		"\n\t $info"
}

command_settings $* ;

function install() {
	
	rpm -q $dockerPackage ;
	if [ "$?" == 0 ] ; then 
		print_line "$dockerPackage was found, skipping install"
		return ;
	fi;
	
	print_with_head "Starting install of core docker"

	yum -y install docker device-mapper-libs device-mapper-event-libs
	 
	print_with_head "adding csapUser user to docker"
	sudo groupadd docker
	sudo gpasswd -a csapUser docker;
		

	
	if [[ "$dockerPackage" != *latest* ]] ; then 
		
		print_with_head "Configuring docker stable"
		backup_and_replace /etc/sysconfig/docker scripts/conf-rh-default/sysconfig-docker.sh ;
	
		print_line "Updating /etc/sysconfig/docker with dockerStorage: $dockerStorage"
		sed -i "s=_CSAP_DOCKER_STORAGE_=$dockerStorage=g" /etc/sysconfig/docker
		
		remoteAllowParam="" ;
		if [ "$allowRemote" == "true" ] ; then 
			remoteAllowParam="-H tcp://0.0.0.0:$dockerPort" ;
			print_line "WARNING: Updating /etc/sysconfig/docker with remoteAllowParam: $remoteAllowParam"
		fi
		sed -i "s=_CSAP_ALLOW_REMOTE_=$remoteAllowParam=g" /etc/sysconfig/docker
		
		backup_and_replace /etc/sysconfig/docker-storage-setup scripts/conf-rh-default/sysconfig-docker-storage-setup.sh  ;
		
	else
		
		rpm -q docker-latest ;
		if [ "$?" != 0 ] ; then 
			print_with_head Installing docker-latest....
			yum -y install docker-latest
		fi;
		
		print_with_head "Updating /etc/sysconfig/docker-latest with dockerStorage: $dockerStorage"
		backup_and_replace /etc/sysconfig/docker-latest scripts/conf-rh-latest/sysconfig-docker-latest.sh ;
		sed -i "s=_CSAP_DOCKER_STORAGE_=$dockerStorage=g" /etc/sysconfig/docker-latest
		
		remoteAllowParam="" ;
		if [ "$allowRemote" == "true" ] ; then 
			remoteAllowParam="-H tcp://0.0.0.0:$dockerPort" ;
			print_with_head "WARNING: Updating /etc/sysconfig/docker-latest with remoteAllowParam: $remoteAllowParam"
		fi
		sed -i "s=_CSAP_ALLOW_REMOTE_=$remoteAllowParam=g" /etc/sysconfig/docker-latest
		
		backup_and_replace /etc/sysconfig/docker-latest-storage-setup scripts/conf-rh-latest/sysconfig-docker-latest-storage-setup.sh  ;
		
		backup_and_replace /etc/docker-latest/daemon.json scripts/conf-rh-latest/daemon.json  ;
		
		backup_and_replace /etc/sysconfig/docker scripts/conf-rh-latest/sysconfig-docker.sh ;
		
		
	fi ;

}

function start() {
	print_with_head "starting docker and enabling via systemctl"

	dockerServiceName="docker-latest.service"
	if [[ "$dockerPackage" != *latest* ]] ; then
		dockerServiceName="docker.service"
	fi
	
	systemctl start $dockerServiceName
	systemctl enable $dockerServiceName
	sleep 3

	print_with_head "systemctl status '$dockerServiceName'"
	systemctl status $dockerServiceName
	
	print_with_head "Running hello-world"
	docker run --name csap-hello-container hello-world
		
}

function clean() {
		print_with_head "Clean was specified: all docker containers will be stopped and all images removed"
		docker ps -a -q
		docker stop $(docker ps -a -q) ; 
		docker rm $(docker ps -a -q) 
		docker rmi $(docker images -a -q) ;
		
		if [[ "$dockerPackage" != *latest* ]] ; then
			systemctl stop docker.service
			systemctl disable docker.service
		else
			systemctl stop docker-latest.service
			systemctl disable docker-latest.service
		fi
		
		
		print_with_head "Docker stopped -  running rm -rf $dockerStorage"
		\rm -rf $dockerStorage
		
		print_with_head "removing docker from system"
		yum -y erase docker docker-latest docker-common docker-ce
		
}

function stop() {
		print_with_head "Stopping docker containers"
		docker ps -a -q
		docker stop $(docker ps -a -q) ;
		
		
		print_with_head "Stopping docker using systemctl: $dockerPackage.service"
		systemctl stop $dockerPackage.service
		systemctl disable $dockerPackage.service


}

#print_with_head "Running $command"

case "$command" in
	
	install)
		install
		;;
	
	clean)
		clean
		;;
	
	stop)
		stop
		;;
	
	start)
		start
		;;
	
	 *)
            echo $"Usage: $0 {install|start|stop|restart|clean}"
            exit 1
esac
