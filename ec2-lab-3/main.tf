#Provider Block
provider "aws" {
    region = "us-east-1"
}

#Provides an EC2 launch template resource
resource "aws_launch_template" "PeeX" {
  name = "Peex"

  block_device_mappings {
    device_name = "/dev/sdf"

    ebs {
      volume_size = 20
    }
  }

  capacity_reservation_specification {
    capacity_reservation_preference = "open"
  }

  cpu_options {
    core_count       = 4
    threads_per_core = 2
  }

  credit_specification {
    cpu_credits = "standard"
  }

  disable_api_stop        = true
  disable_api_termination = true

  ebs_optimized = true

  elastic_gpu_specifications {
    type = "test"
  }

  elastic_inference_accelerator {
    type = "eia1.medium"
  }

  iam_instance_profile {
    name = "test"
  }

  image_id = "ami-06e46074ae430fba6"

  instance_initiated_shutdown_behavior = "terminate"

  instance_market_options {
    market_type = "spot"
  }

  instance_type = "t2.micro"

  kernel_id = "aki-3f896656"

  key_name = "test"

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
    instance_metadata_tags      = "enabled"
  }

  monitoring {
    enabled = true
  }

  network_interfaces {
    associate_public_ip_address = true
  }

  placement {
    availability_zone = "us-west-2a"
  }

  vpc_security_group_ids = ["sg-083ef7e2989f752c2"]

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "test"
    }
  }
}

#Provides step autoscaling group policy with change in capacity adjustment type
resource "aws_autoscaling_policy" "peex" {
  name                   = "peex-terraform-test"
  scaling_adjustment     = 4
  adjustment_type        = "ChangeInCapacity"
  cooldown               = 300
  autoscaling_group_name = aws_autoscaling_group.peex.name
}

#Provides autoscaling group
resource "aws_autoscaling_group" "peex" {
  availability_zones        = ["us-west-2a"]
  name                      = "peex-terraform-test"
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 300
  health_check_type         = "ELB"
  force_delete              = true
  launch_configuration      = aws_launch_configuration.peex.name
}


#Provides launch configuration
data "aws_ami" "amazon_linux" {
  most_recent = true
}

resource "aws_launch_configuration" "peex" {
  name          = "peex"
  image_id      = data.aws_ami.amazon_linux.id
  instance_type = "t2.micro"
}