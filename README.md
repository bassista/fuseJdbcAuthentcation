# Jboss Fuse Jdbc authentication lab
`sh fuseJdbc.sh`

This is a simple script that run for you 3 docker images:
- MySql for storing our user data mysql:5.5
  - address: `localhost:3306` user: root, password: root
- PhpMyAdmin (just to have a convenient way to visualize/modifiy MySql contents): phpmyadmin/phpmyadmin:4.5.3.1-1
  - address: `http://localhost:8080` admin: `root` password: `root`
- Jbosse fuse (**you need to build this image yourself**): https://github.com/paoloantinori/dockerfiles/tree/master/centos/fuse

After that it creates a fabric and update the configuration to authenticate using the MySql server. In this way you will be able to log in in to karaf console or hawtio using credentials stored in MySql:
- user: `fusejdbc` password: `fusejdbc` group: `admin`
- user: `notfusejdbc` password: `notfusejdbc` group: `none`

## Interacting with the Fuse container
When the script finish you should be able to check fuse container's local ports with:
```
$ docker ps
CONTAINER ID        IMAGE                        COMMAND                CREATED             STATUS              PORTS                                                                                                                                                  NAMES
9e996ab8e080        fuse6.2.1:latest               "/bin/sh -c 'service   About an hour ago   Up About an hour    0.0.0.0:49153->44444/tcp, 0.0.0.0:49154->61616/tcp, 0.0.0.0:49155->8101/tcp, 0.0.0.0:49156->8181/tcp, 0.0.0.0:49157->1099/tcp, 0.0.0.0:49158->22/tcp   root
0fb5eabba41c        phpmyadmin/phpmyadmin:4.5.3.1-1   "/run.sh"                6 minutes ago       Up 6 minutes        0.0.0.0:8080->8080/tcp                                                                                                                                 phpmyadmin
7228ea52ec9f        mysql:5.5                         "/entrypoint.sh mysql"   6 minutes ago       Up 6 minutes        0.0.0.0:3306->3306/tcp
```
in this example the hawtio console would be at `http://localhost:49156`, activeMQ at `localhost:49154`, karaf console at `localhost:49155` and ssh into the container at `localhost:49158`.

## NOTE Before launching the script:
Before launching the script you need to build fuse6.2.1 image yourself by download JBoss Fuse distribution from

http://www.jboss.org/products/fuse

The build process will extract in the Docker image all the zip files it will find in your working folder. If it finds more than a file it will put all of them inside the  Docker it's going to be created. Most of the time you will want to have just a single zip file.

## To build your Fuse image:
    # download docker file
	wget https://raw.github.com/paoloantinori/dockerfiles/master/centos/fuse/fuse/Dockerfile

    # check if base image has been updated
	docker pull pantinor/fuse

    # build your docker fuse image. you are expected to have either a copy of jboss-fuse-full-6.2.1.0.redhat-379.zip or a link to that file in the current folder.
    docker build --rm -t fuse6.2.1 .
