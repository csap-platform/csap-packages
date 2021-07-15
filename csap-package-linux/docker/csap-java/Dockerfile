FROM sensus/centos
#FROM centos7:latest

#  
#  EOL:  jdk-11.0.3_linux-x64_bin.tar.gz

ARG jdkDistribution="OpenJDK11U-jdk_x64_linux_11.0.4_11.tar.gz"
ARG packageServer="http://csap-dev01.lab.sensus.net"
ARG javaVersion="openjdk-11.0.4"
ARG javaHome="/java-local/$javaVersion"

ENV JAVA_HOME="$javaHome" \
	PATH="$javaHome/bin:${PATH}" \
	startCommand="java" \
	javaOptions="-version" \
	javaTarget=""

RUN printf "\n\n ________ installing core os tools ________\n\n" && \
	yum -y install wget which unzip && \
	yum -y update bind-license


WORKDIR "/java-local"	
ADD $packageServer/java/OpenJDK11U-jdk_x64_linux_11.0.4_11.tar.gz .

RUN printf "\n\n ________ installing java ________\n\n" && \
	tar -xzf OpenJDK*.tar.gz && \
	rm -rf jdk*.tar.gz && \
	mv *openjdk* $javaVersion


ADD runJava.sh .
RUN chmod +x runJava.sh

ENTRYPOINT [ \
	"/bin/sh",  \
	"-c", \
	"/java-local/runJava.sh" \
]

