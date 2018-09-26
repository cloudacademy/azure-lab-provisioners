#!/usr/bin/env bash
# Install and start Docker
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce-18.06.1.ce-3.el7
systemctl enable docker
systemctl start docker
# Run the web application and set the hostname environment variable
docker run -e hostname=$(hostname) -p 80:80 --restart always -d lrakai/tetris:hostname
