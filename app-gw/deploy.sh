#!/usr/bin/env bash
yum install -y yum-utils device-mapper-persistent-data lvm2
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum install -y docker-ce-18.06.1.ce-3.el7
systemctl enable docker
systemctl start docker
docker run -e hostname=$(hostname) -p 80:80 --restart always -d lrakai/tetris:hostname
