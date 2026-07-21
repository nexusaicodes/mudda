#!/usr/bin/env bash
# Rollback — destroy everything provision.sh created, found by the same tag.
# Makes a failed first attempt cheap to undo. Does NOT touch GitHub secrets or
# the GHCR image; pass --all to also delete the local state file.
#
# Destructive: terminates the instance (and its data volume) and releases the
# Elastic IP. Requires an explicit confirmation.
set -euo pipefail
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

main() {
  require_cmd aws
  load_config
  local instance_id ip
  instance_id="$(state_get INSTANCE_ID)"; ip="$(state_get PUBLIC_IP)"

  warn "This will TERMINATE instance ${instance_id:-<none>} (@ ${ip:-?}) and release its Elastic IP."
  read -r -p "Type the tag '$TAG' to confirm: " reply </dev/tty
  [ "$reply" = "$TAG" ] || die "confirmation did not match — aborted"

  terminate_instance
  release_elastic_ip
  delete_security_group
  ok "AWS resources for '$TAG' removed"
  warn "GitHub secrets/variables and the GHCR image are left intact — remove those by hand if desired."
  [ "${1:-}" = "--all" ] && { rm -f "$STATE_FILE"; ok "cleared local state"; }
}

terminate_instance() {
  local id; id="$(aws_ ec2 describe-instances --filters "Name=tag:Name,Values=$TAG" \
    "Name=instance-state-name,Values=pending,running,stopping,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' 2>/dev/null || true)"
  if [ -n "$id" ] && [ "$id" != "None" ]; then
    log "terminating $id"
    aws_ ec2 terminate-instances --instance-ids "$id" >/dev/null
    aws_ ec2 wait instance-terminated --instance-ids "$id"
  fi
}

release_elastic_ip() {
  local alloc; alloc="$(aws_ ec2 describe-addresses --filters "Name=tag:Name,Values=$TAG" \
    --query 'Addresses[0].AllocationId' 2>/dev/null || true)"
  if [ -n "$alloc" ] && [ "$alloc" != "None" ]; then
    log "releasing Elastic IP $alloc"
    aws_ ec2 release-address --allocation-id "$alloc" >/dev/null 2>&1 || true
  fi
}

# The SG can only be deleted once no instance references it; the terminate wait above handles that.
delete_security_group() {
  local sg; sg="$(aws_ ec2 describe-security-groups --filters "Name=group-name,Values=$TAG-sg" \
    --query 'SecurityGroups[0].GroupId' 2>/dev/null || true)"
  if [ -n "$sg" ] && [ "$sg" != "None" ]; then
    log "deleting security group $sg"
    aws_ ec2 delete-security-group --group-id "$sg" >/dev/null 2>&1 || warn "SG still in use; skipped"
  fi
}

main "$@"
