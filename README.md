# oci-homelab-terraform

Terraform configuration to provision an [Oracle Cloud Always Free](https://www.oracle.com/cloud/free/) ARM64 VM optimised for self-hosting internet-facing web applications with Docker Compose.

## What this deploys

| Resource | Details |
|---|---|
| **Compute** | Ampere A1 Flex — 4 OCPUs, 24 GB RAM, 200 GB boot volume |
| **OS** | Ubuntu 24.04 LTS (Noble), ARM64 |
| **Networking** | VCN + subnet with Internet Gateway; ports 22/80/443 always open |
| **Security** | SSH hardened (no root, no password auth); AppArmor disabled for container workloads |
| **Backups** | Daily incremental + weekly full boot-volume snapshots |
| **Software** | Docker, Docker Compose plugin, `ctop`, `s5cmd`, `htop`, `git` |
| **WireGuard** | Optional — enabled only when `wg_config` is set in `terraform.tfvars` |

## Prerequisites

1. **Oracle Cloud account** — [sign up](https://www.oracle.com/cloud/free/), then [upgrade to PAYG](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/signingup.htm) (you won't be charged while inside Always Free limits)
2. **Terraform** — `brew install hashicorp/tap/terraform`
3. **OCI API key** — generate in the Console under *User Settings → API Keys*, download the `.pem`
4. **SSH key pair** — generate a dedicated key for this VM:
   ```bash
   ssh-keygen -t ed25519 -f ~/.ssh/oci_mamsoft -C "oci-mamsoft"
   ```

## Usage

### 1. Clone and initialise

```bash
git clone https://github.com/MaMissaoui/oci-homelab-terraform.git
cd oci-homelab-terraform
terraform init
```

### 2. Configure

```bash
cp terraform.tfvars.example terraform.tfvars
```

Edit `terraform.tfvars` with your OCI credentials and SSH public key. All other values have sensible defaults for an Always Free setup.

#### Required values

| Variable | Where to find it |
|---|---|
| `oci_connection.tenancy_ocid` | Console → Profile → Tenancy → Copy OCID |
| `oci_connection.user_ocid` | Console → Profile → User Settings → Copy OCID |
| `oci_connection.fingerprint` | Console → User Settings → API Keys |
| `oci_connection.private_key_path` | Local path to the downloaded `.pem` file |
| `vm.ssh_public_keys` | Output of `cat ~/.ssh/oci_mamsoft.pub` |

#### Optional: sudo password

If you want password-based `sudo`, generate a SHA-512 hash and set it as `vm.os.password`:

```bash
python3 -c 'import crypt; print(crypt.crypt("YOUR_PASSWORD", crypt.mksalt(crypt.METHOD_SHA512)))'
```

#### Optional: WireGuard

Leave `wg_config = {}` to skip WireGuard entirely. To enable it, populate the map with your interface config — port 51820 will be opened automatically:

```hcl
wg_config = {
  "wg0" = <<EOF
[Interface]
PrivateKey = <SERVER_PRIVATE_KEY>
Address    = 10.200.0.2/32
ListenPort = 51820

[Peer]
PublicKey          = <CLIENT_PUBLIC_KEY>
AllowedIPs         = 10.200.0.1/32
PersistentKeepalive = 25
EOF
}
```

Generate a key pair with:

```bash
wg genkey | tee privatekey | wg pubkey > publickey
```

### 3. Deploy

```bash
terraform plan
terraform apply
```

Terraform outputs the VM's public IP on success.

### 4. Connect

```bash
ssh -i ~/.ssh/oci_mamsoft mamsoft@<PUBLIC_IP>
```

Docker Compose files can be placed anywhere under the `mamsoft` home directory. The Docker daemon listens on `127.0.0.1` only — expose services via a reverse proxy (e.g. Traefik, Caddy, or nginx-proxy) bound to ports 80/443.

## Availability Domain hunting

Oracle's Always Free A1 instances are in high demand and often show "Out of Capacity". `hunt.sh` automates retrying across all Availability Domains until one succeeds.

```bash
chmod +x hunt.sh

# Run in a tmux session so it survives disconnects
tmux new -s hunt
./hunt.sh
# Ctrl+B, D to detach

# Watch progress
tail -f terraform_hunt.log
```

To receive a notification when the VM is created, set `NOTIFY_CMD` to any script that accepts the public IP as its first argument:

```bash
NOTIFY_CMD="./notify.sh" ./hunt.sh
```

You can also target a specific Availability Domain directly:

```bash
terraform apply -var="availability_domain=2"
```

## Security notes

- Never commit `terraform.tfvars` or `.pem` files — both are in `.gitignore`
- The Docker daemon binds to `127.0.0.1`; do not expose it to the network
- Root login and password authentication are disabled via SSH hardening in cloud-init
