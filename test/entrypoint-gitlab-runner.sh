#!/bin/bash

# Create config.toml template file
# https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runnersmachine-section
# https://gitlab.com/gitlab-org/ci-cd/docker-machine/-/blob/main/docs/drivers/aws.md
# https://gitlab.com/gitlab-org/ci-cd/docker-machine/-/tree/main/drivers/amazonec2
# https://docs.gitlab.com/runner/commands/
# https://docs.gitlab.com/runner/register/index.html#runners-configuration-template-file

# Set error handling
set -euo pipefail

# Always unregister runner on exit
function gitlab_unregister {
    echo "Tearing down runners..."
    
    echo "Stopping runners..."
    # Grafeful Shutdown (wait jobs to finish)
    #pkill -QUIT gitlab-runner

    # Forceful Shutdown (abort current jobs)
    pkill -TERM gitlab-runner

    echo "Unregistering runners..."
    gitlab-runner --debug unregister --all-runners
}

trap gitlab_unregister EXIT SIGHUP SIGINT SIGTERM

GLOBAL_SECTION_CONFIG='/etc/gitlab-runner/config.toml'

runners_userdata_file="/etc/gitlab-runner/runners_userdata.sh"
wget -q https://raw.githubusercontent.com/EliveltonRepolho/aws-ecs-gitlab-runner/main/test/runners_userdata.sh -O $runners_userdata_file

echo "Default config.toml..."
cat ${GLOBAL_SECTION_CONFIG} 2> /dev/null

# Global config file

cat <<EOF >$GLOBAL_SECTION_CONFIG
concurrent = ${RUNNER_CONCURRENT_LIMIT}
check_interval = 0
#log_level = "debug"

[session_server]
  session_timeout = 1800
EOF

idle_minutes=10
idle_time=$(( ${idle_minutes} * 60 ))
echo "using IdleTime: ${idle_time}"

# Per runner config file
function create_runner_config_file {
  local runner_type=$1
  local config_file=$2
  local instance_type=$3
  local is_spot=${4:-false}

cat <<EOF >$config_file
[[runners]]
  name = "echope-erp-gitlab-runner-${runner_type}"
  description = "Gitlab Runner executing Pipeline Jobs in EC2" 
  executor = "docker+machine"
  limit = ${RUNNER_CONCURRENT_LIMIT}
  request_concurrency = ${RUNNER_CONCURRENT_LIMIT}
  environment = [
    "DOCKER_DRIVER=overlay2",
    "DOCKER_TLS_CERTDIR="
  ]
  [runners.docker]
    privileged = true
    disable_cache = true
    tls_verify = true
  [runners.machine]
    IdleTime = ${idle_time}
    MaxBuilds = 10 # We delete the VM after N jobs has finished so we can try to evict running out of space (disk).
    MachineDriver = "amazonec2"
    MachineName = "gitlab-${runner_type}-%s"
    MachineOptions = [
      "amazonec2-iam-instance-profile=${AWS_INSTANCE_PROFILE}",
      "amazonec2-ami=${AWS_AMI}",
      "amazonec2-root-size=${AWS_ROOT_SIZE}",
      "amazonec2-region=${AWS_DEFAULT_REGION}",
      "amazonec2-vpc-id=${AWS_VPC_ID}",
      "amazonec2-subnet-id=${AWS_SUBNET_ID}",
      "amazonec2-zone=${AWS_SUBNET_ZONE}",
      "amazonec2-ssh-user=${AWS_SSH_USER}",
      "amazonec2-security-group=${AWS_SECURITY_GROUP}",
      "amazonec2-instance-type=${instance_type}",
      "amazonec2-request-spot-instance=${is_spot}",
      "amazonec2-monitoring=${AWS_INSTANCE_MONITORING}",
      "amazonec2-userdata=${runners_userdata_file}",
      "amazonec2-tags=stack,echope-erp,stack-env,echope-erp-infra-devops,stack-group,echope-erp-gitlab-ec2-runner-${runner_type}",
    ]
  [runners.cache]
    Type = "${CACHE_TYPE}"
    Shared = ${CACHE_SHARED}
    [runners.cache.s3]
      ServerAddress = "${CACHE_S3_SERVER_ADDRESS}"
      AccessKey = "${CACHE_S3_ACCESS_KEY}"
      SecretKey = "${CACHE_S3_SECRET_KEY}"
      BucketName = "${CACHE_S3_BUCKET_NAME}"
      BucketLocation = "${CACHE_S3_BUCKET_LOCATION}"
EOF
}

TEMPLATE_FILE_GENERAL='./template-general-config.toml'
create_runner_config_file "general" ${TEMPLATE_FILE_GENERAL} ${AWS_INSTANCE_TYPE_GENERAL} "false"

TEMPLATE_FILE_GENERAL_SPOT='./template-general-spot-config.toml'
create_runner_config_file "general" ${TEMPLATE_FILE_GENERAL_SPOT} ${AWS_INSTANCE_TYPE_GENERAL} "true"

TEMPLATE_FILE_MEDIUM='./template-medium-config.toml'
create_runner_config_file "medium" ${TEMPLATE_FILE_MEDIUM} ${AWS_INSTANCE_TYPE_MEDIUM} "false"

TEMPLATE_FILE_MEDIUM_SPOT='./template-medium-spot-config.toml'
create_runner_config_file "medium" ${TEMPLATE_FILE_MEDIUM_SPOT} ${AWS_INSTANCE_TYPE_MEDIUM} "true"

TEMPLATE_FILE_LARGE='./template-large-config.toml'
create_runner_config_file "large" ${TEMPLATE_FILE_LARGE} ${AWS_INSTANCE_TYPE_LARGE} "false"

TEMPLATE_FILE_LARGE_SPOT='./template-large-spot-config.toml'
create_runner_config_file "large" ${TEMPLATE_FILE_LARGE_SPOT} ${AWS_INSTANCE_TYPE_LARGE} "true"

# Register runners
# --debug

# using runner token: https://github.com/npalm/terraform-aws-gitlab-runner/blob/main/template/gitlab-runner.tpl#L26
echo "Registering runner using config.toml template file: $TEMPLATE_FILE_GENERAL"
gitlab-runner --debug register \
--template-config $TEMPLATE_FILE_GENERAL \
--non-interactive \
--run-untagged \
--tag-list "aws:small,aws:general"

echo "Registering runner using config.toml template file: $TEMPLATE_FILE_GENERAL_SPOT"
gitlab-runner --debug register \
--template-config $TEMPLATE_FILE_GENERAL_SPOT \
--non-interactive \
--tag-list "aws:small:spot,aws:general:spot"

echo "Registering runner using config.toml template file: $TEMPLATE_FILE_MEDIUM"
gitlab-runner --debug register \
--template-config $TEMPLATE_FILE_MEDIUM \
--non-interactive \
--tag-list "aws:medium"

echo "Registering runner using config.toml template file: $TEMPLATE_FILE_MEDIUM_SPOT"
gitlab-runner --debug register \
--template-config $TEMPLATE_FILE_MEDIUM_SPOT \
--non-interactive \
--tag-list "aws:medium:spot"

echo "Registering runner using config.toml template file: $TEMPLATE_FILE_LARGE"
gitlab-runner --debug register \
--template-config $TEMPLATE_FILE_LARGE \
--non-interactive \
--tag-list "aws:large"

echo "Registering runner using config.toml template file: $TEMPLATE_FILE_LARGE_SPOT"
gitlab-runner --debug register \
--template-config $TEMPLATE_FILE_LARGE_SPOT \
--non-interactive \
--tag-list "aws:large:spot"

echo "gitlab-runner version..."
gitlab-runner --version

# https://gitlab.com/gitlab-org/gitlab/-/issues/390385
echo "docker-machine version [Before Update]..."
docker-machine --version
wget -q https://gitlab.com/gitlab-org/ci-cd/docker-machine/-/releases/v0.16.2-gitlab.19/downloads/docker-machine-Linux-x86_64 -O /usr/bin/docker-machine
echo "docker-machine version [After Update]..."
docker-machine --version

echo "List available runners..."
gitlab-runner list

echo "Starting runner..."

# background the task
gitlab-runner run &
pid=$!

echo "waiting for runner pid: ${pid}"
wait $pid

echo "leaving script"
