# Deployment Guide — mamsoft VM (no WireGuard)

Step-by-step walkthrough to provision the mamsoft VM on Oracle Cloud Always Free tier.

---

## Step 1 — Oracle Cloud account

1. [Create an OCI account](https://www.oracle.com/cloud/free/) and verify it with a credit card (Oracle charges and immediately reverses ~$1)
2. [Upgrade to Pay As You Go (PAYG)](https://docs.oracle.com/en-us/iaas/Content/GSG/Tasks/signingup.htm) — required to access Always Free A1 instances; you won't be charged while staying within free limits

---

## Step 2 — Generate an OCI API key

1. Log in to the [OCI Console](https://cloud.oracle.com)
2. Click your profile icon (top right) → **User Settings**
3. Under **API Keys**, click **Add API Key** → **Generate API Key Pair**
4. Download the **Private Key** (`.pem` file) and save it to `~/.oci/oci_api_key.pem`
5. Click **Add** — the Console shows a config preview; note the **Fingerprint** value

Collect these values (you'll need them in Step 5):

| Value | Where to find it |
|---|---|
| **Tenancy OCID** | Profile icon → **Tenancy: \<name\>** → Copy OCID |
| **User OCID** | Profile icon → **User Settings** → Copy OCID |
| **Fingerprint** | **User Settings → API Keys** — shown after adding the key |
| **Region** | Shown in the Console URL, e.g. `eu-frankfurt-1` |

---

## Step 3 — Install dependencies

```bash
# Terraform
brew install hashicorp/tap/terraform

# GitHub CLI (optional, for fork management)
brew install gh
```

---

## Step 4 — Clone the repo

```bash
git clone https://github.com/MaMissaoui/oci-homelab-terraform.git
cd oci-homelab-terraform
terraform init
```

---

## Step 5 — Create your tfvars file

```bash
cp terraform.tfvars.example terraform.tfvars
```

Open `terraform.tfvars` and fill in the required values:

```hcl
oci_connection = {
  tenancy_ocid     = "ocid1.tenancy.oc1..xxxx"
  user_ocid        = "ocid1.user.oc1..xxxx"
  fingerprint      = "aa:bb:cc:..."
  private_key_path = "~/.oci/oci_api_key.pem"
  region           = "eu-frankfurt-1"
}

availability_domain = 1   # try 2 or 3 if capacity is unavailable

general = {
  compartment_name    = "mamsoft"
  main_network_cidr   = "172.16.0.0/16"
  private_subnet_cidr = "172.16.0.0/24"
}

vm = {
  name      = "mamsoft"
  ssh_public_keys = [
    "ssh-ed25519 AAAA... oci-mamsoft"   # output of: cat ~/.ssh/oci_mamsoft.pub
  ]

  os = {
    hostname  = "mamsoft"
    username  = "mamsoft"
    password  = ""        # leave empty to use SSH key auth only
    force_dns = []
    wg_config = {}        # empty = WireGuard disabled
  }
}
```

> **SSH key:** generate a dedicated key pair for this VM:
> ```bash
> ssh-keygen -t ed25519 -f ~/.ssh/oci_mamsoft -C "oci-mamsoft"
> ```
> Then paste the contents of `~/.ssh/oci_mamsoft.pub` into `ssh_public_keys`.

> **Password (optional):** to enable password-based `sudo`, generate a hash and paste it into `password`:
> ```bash
> python3 -c 'import crypt; print(crypt.crypt("YOUR_PASSWORD", crypt.mksalt(crypt.METHOD_SHA512)))'
> ```

---

## Step 6 — Review the plan

```bash
terraform plan
```

Expected resources to be created:

- `oci_identity_compartment.identity`
- `oci_core_vcn.main`
- `oci_core_internet_gateway.igw`
- `oci_core_route_table.main`
- `oci_core_default_security_list.main` — opens TCP 22, 80, 443
- `oci_core_subnet.main`
- `oci_core_instance.vm`
- `oci_core_volume_backup_policy.backup`
- `oci_core_volume_backup_policy_assignment.backup`

WireGuard port 51820 should **not** appear in the security list since `wg_config = {}`.

---

## Step 7 — Apply

```bash
terraform apply
```

Type `yes` when prompted. Provisioning takes 3–5 minutes. On success, Terraform prints:

```
Outputs:
vm_public_ip = "X.X.X.X"
```

> **Out of Capacity error?** Oracle A1 instances are in high demand. See [Capacity hunting](#capacity-hunting) below.

---

## Step 8 — Connect via SSH

```bash
ssh -i ~/.ssh/oci_mamsoft mamsoft@<PUBLIC_IP>
```

The VM reboots once after cloud-init completes (AppArmor and sysctl changes). If the first connection attempt is refused, wait 60 seconds and retry.

**Tip:** add a host alias to `~/.ssh/config` so you can connect with just `ssh mamsoft`:

```
Host mamsoft
    HostName      <PUBLIC_IP>
    User          mamsoft
    IdentityFile  ~/.ssh/oci_mamsoft
    IdentitiesOnly yes
```

---

## Step 9 — Deploy a Docker Compose app

Once logged in, create a directory for your app and add a `compose.yml`:

```bash
mkdir ~/myapp && cd ~/myapp
nano compose.yml
```

Example — a simple nginx site:

```yaml
services:
  web:
    image: nginx:alpine
    ports:
      - "80:80"
    volumes:
      - ./html:/usr/share/nginx/html:ro
    restart: unless-stopped
```

Start it:

```bash
docker compose up -d
docker compose ps
```

The app is immediately reachable at `http://<PUBLIC_IP>`.

---

## Capacity hunting

If `terraform apply` fails with `Out of Capacity`, run the included hunting script — it cycles through Availability Domains 1, 2, and 3 until one succeeds:

```bash
chmod +x hunt.sh

# Keep running after disconnect
tmux new -s hunt
./hunt.sh
# Ctrl+B, D  to detach

# Watch the log
tail -f terraform_hunt.log
```

Optionally receive a notification when the VM is created:

```bash
# NOTIFY_CMD receives the public IP as $1
NOTIFY_CMD="./my-notify-script.sh" ./hunt.sh
```

---

## Teardown

To destroy all resources:

```bash
terraform destroy
```

> This permanently deletes the VM, its boot volume, all backups, and the VCN. Make sure to back up any data first.
