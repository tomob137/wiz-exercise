# ---------- OS image: Ubuntu 20.04 (outdated on purpose) ----------
data "aws_ami" "ubuntu_focal" {
  most_recent        = true
  owners             = ["099720109477"] # Canonical, Ubuntu's publisher
  include_deprecated = true             # old images get marked deprecated but still launch
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

resource "aws_key_pair" "wiz" {
  key_name   = "${var.name}-key"
  public_key = var.ssh_public_key
}

# ---------- Firewall ----------
resource "aws_security_group" "mongo_vm" {
  name        = "${var.name}-mongo-vm"
  description = "Mongo VM: SSH open (intentional), Mongo from Kubernetes subnets only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH from the whole internet (INTENTIONAL WEAKNESS)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "MongoDB from the Kubernetes private subnets only"
    from_port   = 27017
    to_port     = 27017
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }

  egress {
    description = "All outbound: package installs, S3 uploads"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ---------- IAM role: over-permissive (INTENTIONAL WEAKNESS) ----------
resource "aws_iam_role" "mongo_vm" {
  name = "${var.name}-mongo-vm-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Full control of EC2: create/delete VMs, security groups, snapshots...
resource "aws_iam_role_policy_attachment" "mongo_vm_ec2_full" {
  role       = aws_iam_role.mongo_vm.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
}

# What it actually needs: write backups to one bucket.
resource "aws_iam_role_policy" "mongo_vm_backup" {
  name = "write-backups"
  role = aws_iam_role.mongo_vm.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["s3:PutObject"]
      Resource = "${aws_s3_bucket.backups.arn}/*"
    }]
  })
}

resource "aws_iam_instance_profile" "mongo_vm" {
  name = "${var.name}-mongo-vm"
  role = aws_iam_role.mongo_vm.name
}

# ---------- The VM ----------
resource "aws_instance" "mongo" {
  ami                         = data.aws_ami.ubuntu_focal.id
  instance_type               = "t3.small"
  subnet_id                   = module.vpc.public_subnets[0]
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.mongo_vm.id]
  iam_instance_profile        = aws_iam_instance_profile.mongo_vm.name
  key_name                    = aws_key_pair.wiz.key_name

  user_data = templatefile("${path.module}/scripts/mongo-setup.sh.tftpl", {
    admin_pw = var.mongo_admin_password
    app_pw   = var.mongo_app_password
    bucket   = aws_s3_bucket.backups.bucket
  })
  user_data_replace_on_change = true

  metadata_options {
    http_tokens = "required" # IMDSv2 only: the hardened metadata service
  }

  root_block_device {
    volume_size = 20
    encrypted   = true
  }

  tags = {
    Name = "${var.name}-mongo"
  }
}

output "vm_public_ip" {
  value = aws_instance.mongo.public_ip
}

output "vm_private_ip" {
  value = aws_instance.mongo.private_ip
}

output "vm_os_image" {
  value = data.aws_ami.ubuntu_focal.name
}