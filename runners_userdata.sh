#!/bin/bash

set -e -x
export DEBIAN_FRONTEND=noninteractive

#redirec all logs
touch /var/log/user-data.log && chmod 777 /var/log/user-data.log
exec > >(tee /var/log/user-data.log) 2>&1

# https://gitlab.com/gitlab-org/gitlab/-/issues/390385#note_1265442367
mkdir -p /etc/docker


# https://repost.aws/knowledge-center/ec2-memory-swap-file
tee create_swap_partition.sh <<EOF
if [ ! -f /swapfile ]; then    
    dd if=/dev/zero of=/swapfile bs=128M count=32
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    swapon -s

    echo "vm.swappiness = 4" >> /etc/sysctl.conf
    sysctl -p
    echo "swap partition created"
fi
EOF
chmod +x create_swap_partition.sh
nohup sh create_swap_partition.sh &

echo "User Data script done"
