#!/bin/bash

##########################################################################################################
# Description:
# This example will guide you through a simple Red Hat JBoss Fuse setup with ldap autentication.
# We are going to start 3 docker container: one openldap server with some users and group preloaded,
# one phpldapadmin just to have a conveninent way to visualize and interact with the ldap server,
# and our fuse insance which we are going to configure for autenticating against the ldap server.
#
# Dependencies:
# - docker
# - sshpass, used to avoid typing the pass everytime (not needed if you are invoking the commands manually)
# to install on Fedora/Centos/Rhel:
# sudo yum install -y docker-io sshpass
# - fuse6.1 docker image:
#   1) download docker file:
#   wget https://raw.github.com/paoloantinori/dockerfiles/master/centos/fuse/fuse/Dockerfile
#
#   2) download Jboss fuse 6.1 from http://www.jboss.org/products/fuse zip and place it in the same directoryof the Dokerfile
#   NOTE: you are expected to have either a copy of jboss-fuse-*.zip or a link to that file in the current folder.
#
#   3) check if base image has been updated:
#   docker pull pantinor/fuse
#
#   4) build your docker fuse image:
#   docker build -rm -t fuse6.2.1 .
#
# Prerequesites:
# - run docker in case it's not already
# sudo service docker start
#
# Notes:
# - if you run the commands, typing them yourself in a shell, you probably won't need all the ssh aliases
#   or the various "sleep" invocations
# - as you may see this script is based on sleep commands, that maybe too short if your hardware is much slower than mine.
#   increase those sleep time if you have to
#######################################################################################################

################################################################################################
#####             Preconfiguration and helper functions. Skip if not interested.           #####
################################################################################################

# scary but it's just for better logging if you run with "sh -x"
export PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

# ulimits values needed by the processes inside the container
ulimit -u 4096
ulimit -n 4096

########## docker lab configuration

# remove old docker containers with the same names
docker stop -t 0 root
docker stop -t 0 mysql
docker stop -t 0 phpmyadmin
docker rm root
docker rm mysql
docker rm phpmyadmin

# expose ports to localhost, uncomment to enable always
EXPOSE_PORTS="-P"
if [[ x$EXPOSE_PORTS == xtrue ]] ; then EXPOSE_PORTS=-P ; fi

# halt on errors
set -e

# create your lab
# run mysql
docker run -it -p 3306:3306 --name mysql -e MYSQL_ROOT_PASSWORD=root -d mysql:5.5
# assign ip addresses to env variable, despite they should be constant on the same machine across sessions
IP_DB=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' mysql)
sleep 10
# populate user schema and data
docker run -it --link mysql:mysql --rm mysql:5.5 sh -c 'exec mysql -h"$MYSQL_PORT_3306_TCP_ADDR" -P"$MYSQL_PORT_3306_TCP_PORT" -uroot -p"$MYSQL_ENV_MYSQL_ROOT_PASSWORD"<<EOF
CREATE DATABASE fuseusers;
USE fuseusers;
CREATE TABLE USERS (
  USERNAME varchar(255) NOT NULL,
  PASSWORD varchar(255) NOT NULL,
  PRIMARY KEY (USERNAME)
);
CREATE TABLE ROLES (
  USERNAME varchar(255) NOT NULL,
  ROLE varchar(255) NOT NULL,
  PRIMARY KEY (USERNAME,ROLE)
);
INSERT INTO USERS VALUES ("fusejdbc","fusejdbc");
INSERT INTO ROLES VALUES ("fusejdbc","admin");
INSERT INTO USERS VALUES ("notfusejdbc","notfusejdbc");
INSERT INTO ROLES VALUES ("notfusejdbc","Monitor");
EOF'

# run phpmyadmin
docker run -it --name phpmyadmin -d -e PMA_HOST=$IP_DB -e PMA_USER=root -e PMA_PASSWORD=root -p 8080:8080 phpmyadmin/phpmyadmin:4.5.3.1-1

# run fuse
docker run -d -t -i $EXPOSE_PORTS --name root fuse6.2.1

# assign ip addresses to env variable, despite they should be constant on the same machine across sessions
IP_ROOT=$(docker inspect --format '{{ .NetworkSettings.IPAddress }}' root)

########### aliases to preconfigure ssh and scp verbose to type options

# full path of your ssh, used by the following helper aliases
SSH_PATH=$(which ssh)
### ssh aliases to remove some of the visual clutter in the rest of the script
# alias to connect to your docker images
alias ssh2host="$SSH_PATH -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PreferredAuthentications=password -oHostKeyAlgorithms=+ssh-dss -o LogLevel=ERROR fuse@$IP_ROOT"
# alias to connect to the ssh server exposed by JBoss Fuse. uses sshpass to script the password authentication
alias ssh2fabric="sshpass -p admin $SSH_PATH -p 8101 -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -o PreferredAuthentications=password -oHostKeyAlgorithms=+ssh-dss -o LogLevel=ERROR admin@$IP_ROOT"

################################################################################################
#####                             Tutorial starts here                                     #####
################################################################################################

echo "waiting 30 sec to ssh into the root container"
sleep 30

# start fuse on root node
# workaround for https://issues.jboss.org/browse/ENTESB-4894
ssh2host  "mv /opt/rh/jboss-fuse-6.2.1.redhat-084/fabric/import/fabric/profiles/mq/amq.profile/org.apache.karaf.command.acl.ssh.properties /opt/rh/org.apache.karaf.command.acl.ssh.properties1"
ssh2host  "mv /opt/rh/jboss-fuse-6.2.1.redhat-084/fabric/import/fabric/profiles/jboss/fuse/full.profile/org.apache.karaf.command.acl.ssh.properties /opt/rh/org.apache.karaf.command.acl.shell.properties2"

ssh2host "/opt/rh/jboss-fuse-*/bin/start"
echo "waiting the Fuse startup for 30 sec"
sleep 30

############################# here you are starting to interact with Fuse/Karaf
# If you want to type the commands manually you have to connect to Karaf. You can do it either with ssh or with the "client" command.
# Ex.
# ssh2fabric

# create a new fabric
ssh2fabric "fabric:create --clean -r localip -g localip --wait-for-provisioning"

# show current containers
ssh2fabric "container-list"

# create a new version of the configuration
ssh2fabric "fabric:version-create 1.1"

sleep 5

# import ldap configuration using git server in fabric
rm -rf ./tmp-git
git clone -b 1.1 http://admin:admin@$IP_ROOT:8181/git/fabric ./tmp-git
cd ./tmp-git/
git checkout 1.1

#add xml ldap configuration to versio 1.1. of default profile
cp ../jdbc-module.xml fabric/profiles/default.profile/
cp ../jdbc-datasource.xml fabric/profiles/default.profile/
cp ../mysql-connector-java-5.1.38.jar fabric/profiles/default.profile/
#add configuration of jdbchost
touch fabric/profiles/default.profile/jdbc.server.properties
echo "jdbchostserver=$IP_DB" >> fabric/profiles/default.profile/jdbc.server.properties
#add a config line to io.fabric8.agent.properties in versio 1.1. of default profile
printf "\nbundle.jdbc-mysql=wrap:profile:mysql-connector-java-5.1.38.jar" >> fabric/profiles/default.profile/io.fabric8.agent.properties
printf "\nbundle.jdbc-realm=blueprint:profile:jdbc-module.xml" >> fabric/profiles/default.profile/io.fabric8.agent.properties
printf "\nbundle.jdbc-datasource=blueprint:profile:jdbc-datasource.xml" >> fabric/profiles/default.profile/io.fabric8.agent.properties

git add *
git config user.email "fuse@jdbc.org"
git config user.name "Mr Fuse Jdbc"
git commit -a -m "Jdbc authentication confiuration"
git push origin 1.1
cd ..
rm -rf ./tmp-git

sleep 5

#upgrade root container to the new configuration
ssh2fabric "fabric:container-upgrade --all 1.1"
