#!/usr/bin/env bash
# Phase 1 — provision the box on EC2. Every resource is found by tag/name and
# created only when absent, so re-running resumes rather than duplicates.
# Produces a stable APP_HOST (<elastic-ip-dashed>.sslip.io) and records the
# instance id / public IP into .state for the later phases.
#
# Grants needed: ec2:{Describe,RunInstances,CreateSecurityGroup,
# AuthorizeSecurityGroupIngress,ImportKeyPair,AllocateAddress,AssociateAddress,
# CreateTags} and ssm:GetParameter (for the Ubuntu AMI lookup).
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

main() {
  require_cmd aws ssh-keygen sed
  load_config
  aws_ sts get-caller-identity >/dev/null || die "aws credentials not working — run 'aws configure'"

  ensure_admin_keypair
  local sg_id ami_id instance_id ip
  sg_id="$(ensure_security_group)"
  ami_id="$(latest_ubuntu_ami)"
  instance_id="$(ensure_instance "$sg_id" "$ami_id")"
  ip="$(ensure_elastic_ip "$instance_id")"

  local app_host="${ip//./-}.sslip.io"
  state_set INSTANCE_ID "$instance_id"
  state_set PUBLIC_IP   "$ip"
  state_set APP_HOST    "$app_host"
  ok "instance $instance_id @ $ip"
  ok "APP_HOST = $app_host"
  log "next: bootstrap-box.sh"
}

# A local admin keypair, imported into EC2 so `ssh -i` works after launch.
ensure_admin_keypair() {
  if [ ! -f "$SSH_KEY" ]; then
    log "generating admin keypair $SSH_KEY"
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "mudda-admin" >/dev/null
  fi
  if ! aws_ ec2 describe-key-pairs --key-names "$TAG-admin" >/dev/null 2>&1; then
    log "importing admin public key as EC2 key pair $TAG-admin"
    aws_ ec2 import-key-pair --key-name "$TAG-admin" \
      --public-key-material "fileb://${SSH_KEY}.pub" >/dev/null
  fi
}

# Security group with 22/80/443 open. AuthorizeIngress is idempotent-friendly:
# a duplicate rule errors, which we swallow.
ensure_security_group() {
  local sg_id
  sg_id="$(aws_ ec2 describe-security-groups \
    --filters "Name=group-name,Values=$TAG-sg" \
    --query 'SecurityGroups[0].GroupId' 2>/dev/null || true)"
  if [ -z "$sg_id" ] || [ "$sg_id" = "None" ]; then
    log "creating security group $TAG-sg"
    sg_id="$(aws_ ec2 create-security-group --group-name "$TAG-sg" \
      --description "mudda app: ssh + http + https" --query 'GroupId')"
    local port
    for port in 22 80 443; do
      aws_ ec2 authorize-security-group-ingress --group-id "$sg_id" \
        --protocol tcp --port "$port" --cidr 0.0.0.0/0 >/dev/null 2>&1 || true
    done
  fi
  printf '%s' "$sg_id"
}

# Canonical's official Ubuntu 24.04 AMI id for this region, via the SSM public parameter.
latest_ubuntu_ami() {
  aws_ ssm get-parameter \
    --name /aws/service/canonical/ubuntu/server/24.04/stable/current/amd64/hvm/ebs-gp3/ami-id \
    --query 'Parameter.Value'
}

# Find a running/pending instance tagged with $TAG; launch one if none exists.
ensure_instance() {
  local sg_id="$1" ami_id="$2" instance_id
  instance_id="$(aws_ ec2 describe-instances \
    --filters "Name=tag:Name,Values=$TAG" "Name=instance-state-name,Values=pending,running" \
    --query 'Reservations[0].Instances[0].InstanceId' 2>/dev/null || true)"
  if [ -z "$instance_id" ] || [ "$instance_id" = "None" ]; then
    log "launching $INSTANCE_TYPE from $ami_id"
    instance_id="$(aws_ ec2 run-instances \
      --image-id "$ami_id" --instance-type "$INSTANCE_TYPE" \
      --key-name "$TAG-admin" --security-group-ids "$sg_id" \
      --block-device-mappings "DeviceName=/dev/sda1,Ebs={VolumeSize=$VOLUME_SIZE_GB,VolumeType=gp3}" \
      --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$TAG}]" \
      --query 'Instances[0].InstanceId')"
  else
    log "reusing existing instance $instance_id"
  fi
  log "waiting for instance to reach running/ok"
  aws_ ec2 wait instance-status-ok --instance-ids "$instance_id"
  printf '%s' "$instance_id"
}

# A tagged Elastic IP associated to the instance — a STABLE address so the
# sslip.io host (and any enrolled passkeys) survive stop/start.
ensure_elastic_ip() {
  local instance_id="$1" alloc_id ip
  alloc_id="$(aws_ ec2 describe-addresses --filters "Name=tag:Name,Values=$TAG" \
    --query 'Addresses[0].AllocationId' 2>/dev/null || true)"
  if [ -z "$alloc_id" ] || [ "$alloc_id" = "None" ]; then
    log "allocating Elastic IP"
    alloc_id="$(aws_ ec2 allocate-address --domain vpc --query 'AllocationId')"
    aws_ ec2 create-tags --resources "$alloc_id" --tags "Key=Name,Value=$TAG" >/dev/null
  fi
  aws_ ec2 associate-address --instance-id "$instance_id" --allocation-id "$alloc_id" >/dev/null
  ip="$(aws_ ec2 describe-addresses --allocation-ids "$alloc_id" --query 'Addresses[0].PublicIp')"
  printf '%s' "$ip"
}

main "$@"
