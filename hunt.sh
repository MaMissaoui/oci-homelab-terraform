#!/bin/bash
# Capacity Hunter: loops through Availability Domains until Terraform apply succeeds.
#
# Optional env vars:
#   NOTIFY_CMD  - command to run on success, receives the public IP as $1
#                 e.g. NOTIFY_CMD="./notify.sh" ./hunt.sh
#   TERRAFORM_DIR - path to the Terraform directory (defaults to script location)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERRAFORM_DIR="${TERRAFORM_DIR:-$SCRIPT_DIR}"
LOG_FILE="$TERRAFORM_DIR/terraform_hunt.log"

echo "Starting Capacity Hunter..." | tee "$LOG_FILE"

cd "$TERRAFORM_DIR"

while true; do
  for ad_num in 1 2 3; do
    echo "----------------------------------------------------" >> "$LOG_FILE"
    echo "[$(date)] Switching to Availability Domain $ad_num..." | tee -a "$LOG_FILE"

    echo "[$(date)] Running terraform apply in AD-$ad_num..." | tee -a "$LOG_FILE"

    if terraform apply -auto-approve -var="availability_domain=$ad_num" >> "$LOG_FILE" 2>&1; then
      VM_IP=$(terraform output -raw vm_public_ip)
      MSG="SUCCESS: Oracle VM created in AD-$ad_num at $(date). Public IP: $VM_IP"
      echo "$MSG" | tee -a "$LOG_FILE"

      if [ -n "${NOTIFY_CMD:-}" ]; then
        $NOTIFY_CMD "$VM_IP" || true
      fi

      exit 0
    fi

    echo "[$(date)] Failed in AD-$ad_num. Waiting 10 seconds before trying next AD..." | tee -a "$LOG_FILE"
    sleep 10
  done

  echo "[$(date)] All ADs failed this round. Sleeping 60 seconds before restarting loop..." | tee -a "$LOG_FILE"
  sleep 60
done
