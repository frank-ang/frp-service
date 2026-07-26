# FRP Server

"FRP Server" publicly-accessible front-end proxy, for a corresponding "FRP Client" back-end service.

There are many ways to run FRP Server, it is implemented here as a cloud server on AWS EC2.

## Overview

A single self-healing AWS EC2 `t3.micro` Spot EC2 instance (Ubuntu 24.04 LTS) with a
static Elastic IP, managed by an Auto Scaling Group,
emitting standard CloudWatch metrics.

## What this builds

| Requirement | How it's implemented |
|---|---|
| 1x t3.micro EC2 instance | `aws_launch_template` (`instance_type = "t3.micro"`) |
| Spot instance | `instance_market_options { market_type = "spot" }` on the launch template |
| Auto-recovering | `aws_autoscaling_group` with `min=max=desired=1`. EC2's native CloudWatch "recover" alarm action is **not supported for Spot instances**, so the standard substitute is a single-instance Auto-Scaling Group ("ASG") to launch replacements automatically. |
| 1 Elastic IP, auto-attached | One `aws_eip` is created outside the instance lifecycle. The launch template's `user_data` script (`user_data.sh.tpl`) runs on every boot, installs the AWS CLI v2 (Ubuntu's stock AMI doesn't ship it like Amazon Linux does), fetches its own instance ID via IMDSv2, and calls `aws ec2 associate-address` to attach the EIP to itself — so any replacement instance re-acquires the same public IP within seconds of booting. |
| IAM instance profile | `aws_iam_role` + `aws_iam_instance_profile`, granting `ec2:AssociateAddress`/`DescribeAddresses` (for the EIP script), `cloudwatch:PutMetricData` (for any future custom metrics), and `AmazonSSMManagedInstanceCore` (so you can shell in via SSM Session Manager without a key pair or open SSH port). |
| Basic CloudWatch metrics | `monitoring { enabled = false }` on the launch template. This is the **default, free, basic monitoring tier** — AWS automatically publishes `CPUUtilization`, `NetworkIn/Out`, `DiskReadOps/WriteOps`, `StatusCheckFailed`, etc. to the `AWS/EC2` namespace every 5 minutes with no agent and no extra IAM permissions required. (Setting `enabled = true` would instead turn on paid 1-minute *detailed* monitoring — left off since only "basic metrics" were requested.) |

## Files

```
.
├── versions.tf        # Terraform + AWS provider version pins
├── variables.tf        # Input variables (region, instance type, networking, etc.)
├── main.tf              # VPC lookups, security group, IAM, EIP, launch template, ASG
├── user_data.sh.tpl     # Boot script that self-associates the Elastic IP
├── outputs.tf           # Useful outputs (EIP, ASG name, etc.)
└── README.md
```

## Usage

Configure `terraform.tfvars` based on example [terraform.tfvars.template](terraform.tfvars.template)

Deploy to the configured AWS account.
```bash
terraform init
terraform plan
terraform apply
```

After apply, find the static IP with:

```bash
terraform output elastic_ip
```

## Notes / design decisions

- **No SSH by default.** `ssh_ingress_cidrs` defaults to `[]`, so port 22 stays
  closed. Connect via AWS Systems Manager Session Manager instead (the
  instance profile already has `AmazonSSMManagedInstanceCore`; the SSM Agent
  is preinstalled on Canonical's Ubuntu AMIs):
  `aws ssm start-session --target <instance-id>`. If you do open SSH, the
  default login user on Ubuntu is `ubuntu` (not `ec2-user`).
- **Spot interruption handling.** `instance_interruption_behavior = "terminate"`
  is set on the launch template, which lets the ASG detect the termination and
  launch a clean replacement, rather than trying to stop/resume — simplest and
  most reliable for a singleton instance.
- **`spot_max_price`** is left `null` by default, which caps your bid at the
  current On-Demand price (AWS's default) — you generally don't need to set
  this lower unless you have a specific budget ceiling.
- **EIP re-association is best-effort at boot.** It retries for ~50 seconds.
  In the rare case the script runs before the instance has network access to
  the EC2 API, check `/var/log/cloud-init-output.log` on the instance.
- **Detailed (1-minute) monitoring** was intentionally left disabled to match
  "basic metrics." Flip `monitoring.enabled` to `true` in `main.tf` if you
  later want 1-minute granularity (incurs additional cost).
