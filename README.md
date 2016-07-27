## HPCC-Docker-Ansible Manage HPCC Cluster with Ansible On Kubernetes Environment
Reference https://hub.docker.com/r/hpccsystems/ansible-ce/ for HPCC Docker images usage

## Prerequisites
Install [Docker](https://docs.docker.com/engine/installation/) and [Docker-compose](https://docs.docker.com/compose/install/)
Ensure your Docker machine is running. For example if you use Virtualbox, or Docker daemon on native Linux, verify that it is running.

## Build HPCC Docker Ansible Images

Checkout the git repository:
```sh
git clone https://github.com/hpcc-kubernetes/HPCC-DockerAnsible.git
```
Check if the image already exists locally or not:
```sh
docker images
```
If the "REPOSITORY" and 'TAG' fields are the same as the ones you want to build, you need remove existing ones first:
```sh
docker rmi <IMAGE ID>
```
Create the build directory.  For example,  *build* and cd into it.
Depending on which you want to build (Ubuntu Trusty HPCC version), you can use a help script
under HPCC-Docker-Ansible or modify them or call HPCC-Docker-Ansible/build.sh. For example to build HPCC 6.0.2-1 on Trusty:
```sh
../HPCC-Docker-Ansible/build.sh -l <Linux codename> -s hpcc5 -v 6.0.2-1.
```
If every build runs OK, the output will display "successfully ....".
Docker images will show:
```sh
docker images
```

