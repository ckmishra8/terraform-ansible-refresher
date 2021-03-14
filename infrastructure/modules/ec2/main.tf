resource "aws_security_group" "public_sg" {
  name        = "public_sg"
  description = "Public SG"

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Public SG"
  }
}

data "aws_ami" "linux2" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }

  filter {
    name   = "name"
    values = ["amzn2-ami-hvm*"]
  }
}

variable "ec2_tags" {
  description = "Tags for EC2 Instances"
  default = [
    {
      Name = "Frontend"
    },
    {
      Name = "Backend"
    },
    {
      Name = "Backend"
    },
    {
      Name = "DB"
    }
  ]
}

variable "instance_profile" {
  description = "EC2 Instance profile name"
  default     = "instance_profile"
}

resource "aws_iam_instance_profile" "instance_profile" {
  name = var.instance_profile
  role = aws_iam_role.role.name
}

resource "aws_iam_role" "role" {
  name = "instance_profile_role"
  path = "/"

  inline_policy {
    name = "inline_policy"
    policy = jsonencode(
      {
        Version = "2012-10-17"
        Statement = [
          {
            Action = [
              "*"
            ]
            Effect   = "Allow"
            Resource = "*"
          },
        ]
      }
    )
  }

  assume_role_policy = jsonencode(
    {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Action" : "sts:AssumeRole",
          "Principal" : {
            "Service" : [
              "ec2.amazonaws.com",
              "ssm.amazonaws.com"
            ]
          },
          "Effect" : "Allow",
          "Sid" : "AssumeRolePolicy"
        }
      ]
    }
  )
}

resource "aws_instance" "nodes" {
  count         = length(var.ec2_tags)
  ami           = data.aws_ami.linux2.id
  instance_type = "t2.medium"
  security_groups = [
    aws_security_group.public_sg.name
  ]
  key_name             = "ec2-ssh"
  user_data            = file("../../../installer.sh")
  iam_instance_profile = var.instance_profile
  tags                 = var.ec2_tags[count.index]
  depends_on = [
    aws_security_group.public_sg,
    aws_iam_instance_profile.instance_profile
  ]
}

resource "aws_instance" "control_node" {
  ami           = data.aws_ami.linux2.id
  instance_type = "t2.medium"
  security_groups = [
    aws_security_group.public_sg.name
  ]
  key_name             = "ec2-ssh"
  user_data            = file("../../../installer.sh")
  iam_instance_profile = var.instance_profile
  tags = {
    Name = "Control_Node"
  }
  depends_on = [
    aws_security_group.public_sg,
    aws_iam_instance_profile.instance_profile
  ]

  connection {
    type        = "ssh"
    user        = "ec2-user"
    private_key = file("~/.ssh/ec2-ssh")
    host        = aws_instance.control_node.public_ip
  }

  provisioner "file" {
    source      = "../../../dynamic_inventory.py"
    destination = "/tmp/dynamic_inventory.py"
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 120",
      "sudo chmod +x /tmp/dynamic_inventory.py",
      "python3 /tmp/dynamic_inventory.py"
    ]
  }
}
