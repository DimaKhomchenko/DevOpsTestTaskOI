#!/bin/bash
sudo yum -y update
sudo yum -y install docker
sudo systemctl enable docker
sudo systemctl start docker
sudo docker pull nginxdemos/nginx-hello
sudo docker run -p 8080:8080 -d nginxdemos/nginx-hello