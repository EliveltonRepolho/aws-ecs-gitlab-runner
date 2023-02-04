#!/bin/bash -e

region=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)

curl -s https://raw.githubusercontent.com/EliveltonRepolho/aws-ecs-gitlab-runner/main/amazon-cloudwatch-agent-ec2-config.json

sudo apt -qq update && sudo apt install -q -y collectd amazon-cloudwatch-agent ec2-instance-connect && \
  sudo wget https://s3.${region}.amazonaws.com/amazoncloudwatch-agent-${region}/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb && \
  sudo dpkg -i -E ./amazon-cloudwatch-agent.deb && \
  sudo /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:amazon-cloudwatch-agent-config.json -s
