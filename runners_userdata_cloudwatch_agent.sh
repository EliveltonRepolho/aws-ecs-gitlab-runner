#!/bin/bash -ex

#redirec all logs
touch /var/log/user-data.log && chmod 777 /var/log/user-data.log
exec > >(tee /var/log/user-data.log) 2>&1

region=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
awslogs_group="__AWSLOGS_GROUP__"

# it is not working because we need to restar docker services (not doing this because the gitlab job is already started)
mkdir -p /etc/docker
tee /etc/docker/daemon.json <<EOF
{
  "log-driver": "awslogs",
  "log-opts": {
    "awslogs-region": "${region}",
    "awslogs-group": "${awslogs_group}",
    "awslogs-stream": "gitlab-runner-ec2-instance-${instance_id}-docker"
  }
}
EOF

for i in {1..7}; do
  echo "Attempt: ---- " $i
  apt -qq update && break || sleep 60
done

apt install -q -y collectd ec2-instance-connect

wget -q https://raw.githubusercontent.com/EliveltonRepolho/aws-ecs-gitlab-runner/main/amazon-cloudwatch-agent-ec2-config.json
sed -i.bak s/__LOG_GROUP_NAME__/`echo $awslogs_group`/g amazon-cloudwatch-agent-ec2-config.json

wget https://s3.${region}.amazonaws.com/amazoncloudwatch-agent-${region}/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i -E ./amazon-cloudwatch-agent.deb
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl -a fetch-config -m ec2 -c file:amazon-cloudwatch-agent-ec2-config.json -s
