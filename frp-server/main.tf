###############################################################################
# Data lookups: default VPC/subnets (used unless var.vpc_id/subnet_ids given)
###############################################################################

data "aws_vpc" "selected" {
  id      = var.vpc_id
  default = var.vpc_id == null ? true : null
}

data "aws_subnets" "selected" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

locals {
  subnet_ids = length(var.subnet_ids) > 0 ? var.subnet_ids : data.aws_subnets.selected.ids

  common_tags = merge(
    {
      Project   = var.project_name
      ManagedBy = "terraform"
    },
    var.tags
  )
}

# Latest Ubuntu 24.04 LTS (Noble) AMI (x86_64), published by Canonical.
# Unlike Amazon Linux, stock Ubuntu AMIs do not ship the AWS CLI, so the
# user-data script installs it on first boot before associating the EIP.
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

###############################################################################
# Security group
###############################################################################

resource "aws_security_group" "instance" {
  name_prefix = "${var.project_name}-"
  description = "SG for ${var.project_name} spot instance"
  vpc_id      = data.aws_vpc.selected.id

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = length(var.ssh_ingress_cidrs) > 0 ? [1] : []
    content {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = var.ssh_ingress_cidrs
    }
  }

  tags = merge(local.common_tags, { Name = "${var.project_name}-sg" })

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# IAM role / instance profile
#   - ec2:AssociateAddress so the instance can self-attach the Elastic IP
#   - cloudwatch:PutMetricData for completeness (basic EC2 metrics like
#     CPUUtilization, NetworkIn/Out, etc. are published automatically by AWS
#     at 5-minute intervals at no extra cost and need no IAM permission or
#     agent at all -- this just covers any custom metrics you add later)
#   - AmazonSSMManagedInstanceCore so you can reach the instance via Session
#     Manager without opening port 22 or managing a key pair
###############################################################################

resource "aws_iam_role" "instance" {
  name_prefix        = "${var.project_name}-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json
  tags               = local.common_tags
}

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "instance_permissions" {
  statement {
    sid       = "AssociateElasticIP"
    effect    = "Allow"
    actions   = ["ec2:AssociateAddress", "ec2:DescribeAddresses"]
    resources = ["*"]
  }

  statement {
    sid       = "PutCloudWatchMetrics"
    effect    = "Allow"
    actions   = ["cloudwatch:PutMetricData"]
    resources = ["*"]
  }
}

resource "aws_iam_role_policy" "instance" {
  name_prefix = "${var.project_name}-"
  role        = aws_iam_role.instance.id
  policy      = data.aws_iam_policy_document.instance_permissions.json
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "instance" {
  name_prefix = "${var.project_name}-"
  role        = aws_iam_role.instance.name
}

###############################################################################
# Elastic IP
#   Created once, outside the ASG/instance lifecycle, so it survives spot
#   interruptions and ASG-driven instance replacement. The launch template's
#   user-data script re-associates it to whichever instance boots next.
###############################################################################

resource "aws_eip" "this" {
  domain = "vpc"
  tags   = merge(local.common_tags, { Name = "${var.project_name}-eip" })
}

###############################################################################
# Launch template
#   - Spot instance via instance_market_options
#   - t3.micro
#   - Basic (free, 5-min) CloudWatch monitoring -- this is the "monitoring"
#     block set to false; AWS still auto-publishes basic EC2 metrics
#   - IMDSv2 required (more secure metadata access, matches user-data script)
###############################################################################

resource "aws_launch_template" "this" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.ubuntu.id
  instance_type = var.instance_type
  key_name      = var.key_name

  iam_instance_profile {
    arn = aws_iam_instance_profile.instance.arn
  }

  vpc_security_group_ids = [aws_security_group.instance.id]

  instance_market_options {
    market_type = "spot"

    spot_options {
      spot_instance_type            = "one-time"
      max_price                     = var.spot_max_price
      instance_interruption_behavior = "terminate"
    }
  }

  # Basic monitoring (enabled = false) is the free, default tier: AWS
  # publishes CPUUtilization, NetworkIn/Out, DiskRead/WriteOps, StatusCheck,
  # etc. to CloudWatch every 5 minutes automatically, no agent required.
  monitoring {
    enabled = true
  }

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 2
  }

  user_data = base64encode(templatefile("${path.module}/user_data.sh.tpl", {
    eip_allocation_id = aws_eip.this.id
  }))

  tag_specifications {
    resource_type = "instance"
    tags          = merge(local.common_tags, { Name = "${var.project_name}-instance" })
  }

  tag_specifications {
    resource_type = "volume"
    tags          = merge(local.common_tags, { Name = "${var.project_name}-volume" })
  }

  tags = local.common_tags
}

###############################################################################
# Auto Scaling Group (min=max=desired=1)
#   This is the "auto-recovery" mechanism for the spot instance: EC2's native
#   CloudWatch "recover" alarm action does NOT support Spot instances, so the
#   standard pattern is a single-instance ASG. If the spot instance is
#   interrupted, fails an EC2 health check, or is terminated for any reason,
#   the ASG launches a fresh replacement (a new spot request) automatically,
#   and the user-data script re-attaches the Elastic IP to it.
###############################################################################

resource "aws_autoscaling_group" "this" {
  name_prefix         = "${var.project_name}-"
  vpc_zone_identifier = local.subnet_ids

  min_size         = 1
  max_size         = 1
  desired_capacity = 1

  health_check_type         = "EC2"
  health_check_grace_period = 300
  default_cooldown          = 60

  launch_template {
    id      = aws_launch_template.this.id
    version = "$Latest"
  }

  # Replace one at a time, never below min capacity, when the launch
  # template changes (e.g. AMI/instance_type updates via terraform apply).
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 0
      instance_warmup        = 60
    }
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-instance"
    propagate_at_launch = true
  }

  dynamic "tag" {
    for_each = local.common_tags
    content {
      key                 = tag.key
      value               = tag.value
      propagate_at_launch = true
    }
  }

  lifecycle {
    create_before_destroy = true
  }
}
