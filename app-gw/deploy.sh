#!/usr/bin/env bash
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y docker-ce-18.06.1.ce-3.el7
sudo systemctl enable docker
sudo systemctl start docker
sudo docker run -e hostname=$(hostname) -p 80:80 --restart always -d lrakai/tetris:hostname
