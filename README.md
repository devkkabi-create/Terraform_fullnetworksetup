# Terraform AWS: Public EC2 Instance in a Custom VPC

A beginner-friendly Terraform project that builds a small AWS network from scratch and launches an EC2 instance you can SSH into. It is organised into two reusable modules, `network` and `compute`.

## What it creates

| # | Resource | Terraform type | Module |
|---|----------|----------------|--------|
| 1 | VPC | `aws_vpc` | network |
| 2 | Public subnet | `aws_subnet` | network |
| 3 | Internet gateway | `aws_internet_gateway` | network |
| 4 | Route table (`0.0.0.0/0` to the internet gateway) | `aws_route_table` | network |
| 5 | Route table association | `aws_route_table_association` | network |
| 6 | Security group (SSH from one IP only) | `aws_security_group` | compute |
| 7 | EC2 instance (Amazon Linux 2023, `t3.micro`) | `aws_instance` | compute |

The AMI is looked up at plan time from the public SSM parameter for the latest Amazon Linux 2023 image, so it works in any region and never goes stale.

## Architecture

```
You (internet)
   |
Internet gateway      <- front door of the VPC
   |
Route table           <- sends 0.0.0.0/0 to the gateway
   |
Public subnet         <- 10.0.1.0/24
   |
Security group        <- allows SSH (port 22) from your IP only
   |
EC2 instance
```

## Project structure

```
.
├── main.tf              # provider and module calls
├── variable.tf          # root input variables
├── output.tf            # root outputs (instance public IP)
├── versions.tf          # Terraform and provider version pins
├── terraform.tfvars     # your values (see below)
├── .gitignore
└── modules/
    ├── network/         # VPC, subnet, internet gateway, route table
    │   ├── main.tf
    │   ├── variable.tf
    │   └── output.tf
    └── compute/         # security group, AMI lookup, EC2 instance
        ├── main.tf
        ├── variable.tf
        └── output.tf
```

Modules share data only through outputs and inputs wired in the root: `network` outputs `vpc_id` and `subnet_id`, and the root passes them into `compute`.

## Prerequisites

- An AWS account with credentials configured (`aws configure`)
- [Terraform](https://developer.hashicorp.com/terraform/install) 1.5 or newer
- [AWS CLI](https://aws.amazon.com/cli/)
- An existing **EC2 key pair** in the region you deploy to (key pairs are regional)
- Your public IP address (https://checkip.amazonaws.com)

## Configuration

Set your values in `terraform.tfvars`:

```hcl
region           = "us-east-1"
vpc_cidr         = "10.0.0.0/16"
subnet_cidr      = "10.0.1.0/24"
vpc_name         = "my-terraform-vpc"
key_name         = "terraform_module"        # must already exist in the region
instance_type    = "t3.micro"
allowed_ssh_cidr = "YOUR.PUBLIC.IP.HERE/32"  # the /32 is required
```

| Variable | Description |
|----------|-------------|
| `region` | AWS region to deploy to |
| `vpc_cidr` | CIDR block for the VPC |
| `subnet_cidr` | CIDR block for the public subnet (must sit inside the VPC range) |
| `vpc_name` | Name tag used for the VPC and as a prefix for related resources |
| `key_name` | Name of an existing EC2 key pair in that region |
| `instance_type` | EC2 instance type |
| `allowed_ssh_cidr` | CIDR allowed to SSH in. Use your own IP with `/32`, never `0.0.0.0/0` |

## Create the key pair (if you don't have one)

```bash
aws ec2 create-key-pair --region us-east-1 --key-name terraform_module \
  --key-type rsa --key-format pem \
  --query "KeyMaterial" --output text > terraform_module.pem
```

AWS shows the private key only once. Keep the `.pem` file safe and never commit it.

## Usage

```bash
terraform init -upgrade      # download providers and modules
terraform fmt -recursive     # format code
terraform validate           # check syntax and wiring
terraform plan               # preview: expect 7 resources to add
terraform apply              # create everything (type yes)
```

When it finishes, Terraform prints the instance's public IP:

```
instance_public_ip = "x.x.x.x"
```

## Connect to the instance

```bash
ssh -i terraform_module.pem ec2-user@<instance_public_ip>
```

On Windows, SSH rejects key files that other users can read. If you see `UNPROTECTED PRIVATE KEY FILE`, remove the extra permissions:

```cmd
icacls terraform_module.pem /inheritance:r
icacls terraform_module.pem /remove "NT AUTHORITY\Authenticated Users"
icacls terraform_module.pem /remove "BUILTIN\Users"
icacls terraform_module.pem /grant:r "%USERNAME%:R"
```

Success looks like the Amazon Linux 2023 banner and a prompt such as `[ec2-user@ip-10-0-1-71 ~]$`.

## Verify in the AWS Console

Make sure the region dropdown matches your `region` value, then check:

- **VPC > Your VPCs:** `my-terraform-vpc` with `10.0.0.0/16` (the **Resource map** tab shows everything connected)
- **Subnets:** `10.0.1.0/24` with auto-assign public IPv4 enabled
- **Internet gateways:** state **Attached**
- **Route tables:** `0.0.0.0/0` points to the internet gateway, and the subnet is associated
- **Security groups:** `allow-ssh` with inbound TCP 22 from your `/32`
- **EC2 > Instances:** running, 2/2 status checks passed

You can also run `terraform state list` (7 resources) and `terraform output`.

## Clean up

```bash
terraform destroy
```

Type `yes`. It should report `Destroy complete! Resources: 7 destroyed.` Destroying practice resources avoids ongoing charges.

## Troubleshooting

| Error | Cause | Fix |
|-------|-------|-----|
| `InvalidKeyPair.NotFound` | Key pair name doesn't exist in that region or account | Create or import it in the same region; check with `aws ec2 describe-key-pairs --region <region>` |
| `is not a valid CIDR block` | IP given without a prefix length | Use `x.x.x.x/32` |
| `Unsupported attribute ... no attributes` | Module is missing an `output` block | Add the output in the module's `output.tf` |
| `Identity file ... not accessible` | Ran `ssh` from a folder without the key | `cd` to the key's folder or use the full path with `-i` |
| `UNPROTECTED PRIVATE KEY FILE` | Key file readable by other users | Fix permissions as shown above |
| SSH times out | Your public IP changed, or no route or public IP | Re-check your IP, update `allowed_ssh_cidr`, and run `terraform apply` |

## Security notes

- Never open SSH to `0.0.0.0/0`. Restrict it to your own IP with `/32`.
- Never commit `.pem` files, `.tfstate` files or the `.terraform/` directory. They are covered by `.gitignore`.
- `terraform.tfvars` contains your public IP. If you prefer not to publish it, add it to `.gitignore` and commit a `terraform.tfvars.example` with placeholder values instead.
- Commit `.terraform.lock.hcl` so provider versions stay consistent.

## Concepts covered

Providers, resources, data sources, variables, outputs, modules, state, the `init / plan / apply / destroy` workflow, CIDR notation, public vs private subnets, ingress and egress rules, and key-pair based SSH access.

## Ideas for next steps

1. Add a second subnet in another availability zone.
2. Add a private subnet with a NAT gateway.
3. Move `instance_name` into a root variable.
4. Split into `dev` and `prod` environments with separate state.
5. Store state remotely in S3.
6. Replace SSH keys with SSM Session Manager so port 22 can stay closed.
