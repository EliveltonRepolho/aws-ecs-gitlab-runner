#!/bin/bash

# Set error handling
set -euo pipefail

# Always unregister runner on exit
function gitlab_unregister {
    echo "Unregistering runner..."
    gitlab-runner unregister --all-runners
}

trap gitlab_unregister EXIT SIGHUP SIGINT SIGTERM

TEMPLATE_FILE_GENERAL='./template-general-config.toml'
TEMPLATE_FILE_IT='./template-it-config.toml'
# Create config.toml template file
# https://docs.gitlab.com/runner/configuration/advanced-configuration.html#the-runnersmachine-section
# https://gitlab.com/gitlab-org/ci-cd/docker-machine/-/blob/main/docs/drivers/aws.md
# https://gitlab.com/gitlab-org/ci-cd/docker-machine/-/tree/main/drivers/amazonec2
cat <<EOF >$TEMPLATE_FILE_GENERAL
concurrent = ${RUNNER_CONCURRENT_LIMIT}
check_interval = 0

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
    MachineName = "gitlab-docker-machine-general-%s"
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

cat <<EOF >$TEMPLATE_FILE_GENERAL
concurrent = ${RUNNER_CONCURRENT_LIMIT}
check_interval = 0

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
    MachineName = "gitlab-docker-machine-it-%s"
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
# https://docs.gitlab.com/runner/commands/
# --debug
gitlab-runner --debug register \
--template-config $TEMPLATE_FILE_GENERAL \
--non-interactive \
--name "ci-runner-general" \
--description "Gitlab Runner executing Pipeline Jobs in EC2" \
--limit ${RUNNER_CONCURRENT_LIMIT} \
--request-concurrency ${RUNNER_CONCURRENT_LIMIT} \
--run-untagged

echo "Registering runner using config.toml template file: $TEMPLATE_FILE_IT"
gitlab-runner --debug register \
--template-config $TEMPLATE_FILE_IT \
--non-interactive \
--name "ci-runner-it" \
--description "Gitlab Runner executing Pipeline Jobs in EC2 with Integration Tests configuration" \
--limit ${RUNNER_CONCURRENT_LIMIT} \
--request-concurrency ${RUNNER_CONCURRENT_LIMIT} \
--tag-list "tests-integration"

echo "gitlab-runner version..."
gitlab-runner --version

echo "List available runners..."
gitlab-runner list

echo "Current config.toml..."
cat /etc/gitlab-runner/config.toml 2> /dev/null

echo "Starting runner..."
gitlab-runner run
