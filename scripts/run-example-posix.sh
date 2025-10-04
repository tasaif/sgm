#!/usr/bin/env bash

sudo docker stop example-ubuntu && sudo docker rm example-ubuntu
sudo docker run -d --name example-ubuntu -p 2200:22 ubuntu:24.04 sleep infinity
