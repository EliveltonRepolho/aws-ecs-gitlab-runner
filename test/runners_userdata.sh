#!/bin/bash -ex

#redirec all logs
touch /var/log/user-data.log && chmod 777 /var/log/user-data.log
exec > >(tee /var/log/user-data.log) 2>&1

region=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)

apt -qq update

apt install -q -y collectd ec2-instance-connect

wget -q https://raw.githubusercontent.com/EliveltonRepolho/aws-ecs-gitlab-runner/main/test/amazon-cloudwatch-agent-ec2-config.json
wget https://s3.${region}.amazonaws.com/amazoncloudwatch-agent-${region}/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:amazon-cloudwatch-agent-ec2-config.json -s

mkdir -p /etc/docker
tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "awslogs",
  "log-opts": {
    "awslogs-region": "${region}",
    "awslogs-group": "echope-fork-infra-devops-gitlab-runner-ecs-log-group",
    "awslogs-stream": "gitlab-runner-ec2-instance-${instance_id}-docker"
  }
}
EOF

service docker ps
#service docker restart

