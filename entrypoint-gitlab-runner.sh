#!/bin/bash

# Set error handling
set -euo pipefail

# Always unregister runner on exit
function gitlab-unregister {
    echo "Unregistering runner..."
    gitlab-runner unregister --all-runners
}

trap 'gitlab-unregister' EXIT SIGHUP SIGINT SIGTERM

# Define runner tags
# https://gitlab.com/gitlab-org/charts/gitlab-runner/-/blob/main/values.yaml#L203
if [ -n "${RUNNER_TAG_LIST:-}" ]
then
    RUNNER_TAG_LIST_OPT=("tags = $RUNNER_TAG_LIST")
else
    RUNNER_TAG_LIST_OPT=("runUntagged = true")
fi

TEMPLATE_FILE='./template-config.toml'
# Create config.toml template file
# https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runnersmachine-section
# https://gitlab.com/gitlab-org/ci-cd/docker-machine/-/blob/main/docs/drivers/aws.md
# https://gitlab.com/gitlab-org/ci-cd/docker-machine/-/tree/main/drivers/amazonec2
cat <<EOF >$TEMPLATE_FILE

concurrent = 4

[[runners]]
  name = "echope-gitlab-runner"
  description = "Gitlab Runner executing Pipeline Jobs in EC2" 
  executor = "docker+machine"
  limit = 2
  environment = ["DOCKER_DRIVER=overlay2", "DOCKER_TLS_CERTDIR="]
  ${RUNNER_TAG_LIST_OPT}
  [runners.docker]
    privileged = true
    disable_cache = true
    tls_verify = true
  [runners.machine]
    IdleTime = 60
    MachineDriver = "amazonec2"
    MachineName = "gitlab-docker-machine-%s"
    MachineOptions = [
      "amazonec2-ami=${AWS_AMI}",
      "amazonec2-root-size=${AWS_ROOT_SIZE}",
      "amazonec2-region=${AWS_DEFAULT_REGION}",
      "amazonec2-vpc-id=${AWS_VPC_ID}",
      "amazonec2-subnet-id=${AWS_SUBNET_ID}",
      "amazonec2-zone=${AWS_SUBNET_ZONE}",
      "amazonec2-use-private-address=true",
      "amazonec2-ssh-user=${AWS_SSH_USER}",
      "amazonec2-security-group=${AWS_SECURITY_GROUP}",
      "amazonec2-instance-type=${AWS_INSTANCE_TYPE}",
      "amazonec2-tags=stack,echope,stack-env,echope-infra-devops,stack-group,echope-gitlab-ec2-runner",
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

echo "Registering runner using config.toml template file: $TEMPLATE_FILE"
gitlab-runner register \
--template-config $TEMPLATE_FILE \
--non-interactive

# Native env var seems to be broken for security group

echo "Starting runner..."
# Start Runner
gitlab-runner run
