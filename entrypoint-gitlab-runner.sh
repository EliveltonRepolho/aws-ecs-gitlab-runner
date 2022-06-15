#!/bin/bash

# Create config.toml template file
# https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runnersmachine-section
# https://gitlab.com/gitlab-org/ci-cd/docker-machine/-/blob/main/docs/drivers/aws.md
# https://gitlab.com/gitlab-org/ci-cd/docker-machine/-/tree/main/drivers/amazonec2
# https://docs.gitlab.com/runner/commands/

# Set error handling
set -euo pipefail

# Always unregister runner on exit
function gitlab_unregister {
    echo "Unregistering runner..."
    gitlab-runner unregister --all-runners
}

trap gitlab_unregister EXIT SIGHUP SIGINT SIGTERM

GLOBAL_SECTION_CONFIG='/etc/gitlab-runner/config.toml'

echo "Default config.toml..."
cat ${GLOBAL_SECTION_CONFIG} 2> /dev/null

# Override default config.toml
cat <<EOF >$GLOBAL_SECTION_CONFIG
concurrent = ${RUNNER_CONCURRENT_LIMIT}
check_interval = 0

[session_server]
  session_timeout = 1800
EOF

TEMPLATE_FILE_GENERAL='./template-general-config.toml'
cat <<EOF >$TEMPLATE_FILE_GENERAL
[[runners]]
  name = "echope-erp-gitlab-runner-general"
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
    IdleTime = 60
    MaxBuilds = 10 # We delete the VM after N jobs has finished so we can try to evict running out of space (disk).
    MachineDriver = "amazonec2"
    MachineName = "gitlab-general-%s"
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
      "amazonec2-instance-type=${AWS_INSTANCE_TYPE_GENERAL}",
      "amazonec2-tags=stack,echope-erp,stack-env,echope-erp-infra-devops,stack-group,echope-erp-gitlab-ec2-runner",
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

TEMPLATE_FILE_IT='./template-it-config.toml'
cat <<EOF >$TEMPLATE_FILE_IT
[[runners]]
  name = "echope-erp-gitlab-runner-integration-tests"
  description = "Gitlab Runner executing Pipeline Jobs in EC2 with Integration Tests configuration" 
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
    IdleTime = 60
    MaxBuilds = 10 # We delete the VM after N jobs has finished so we can try to evict running out of space (disk).
    MachineDriver = "amazonec2"
    MachineName = "gitlab-it-%s"
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
      "amazonec2-instance-type=${AWS_INSTANCE_TYPE_IT}",
      "amazonec2-tags=stack,echope-erp,stack-env,echope-erp-infra-devops,stack-group,echope-erp-gitlab-ec2-runner-it",
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

echo "Registering runner using config.toml template file: $TEMPLATE_FILE_GENERAL"

# --debug
gitlab-runner --debug register \
--template-config $TEMPLATE_FILE_GENERAL \
--non-interactive \
--run-untagged

echo "Registering runner using config.toml template file: $TEMPLATE_FILE_IT"
gitlab-runner --debug register \
--template-config $TEMPLATE_FILE_IT \
--non-interactive \
--tag-list "test:integration:browser"

echo "gitlab-runner version..."
gitlab-runner --version

echo "List available runners..."
gitlab-runner list

echo "Starting runner..."
gitlab-runner run
