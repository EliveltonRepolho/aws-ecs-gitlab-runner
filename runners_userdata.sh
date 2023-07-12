#!/bin/bash

# https://gitlab.com/gitlab-org/gitlab/-/issues/390385#note_1265442367
mkdir -p /etc/docker


echo "Create swap partition"
# https://repost.aws/knowledge-center/ec2-memory-swap-file
dd if=/dev/zero of=/swapfile bs=128M count=32
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
swapon -s
