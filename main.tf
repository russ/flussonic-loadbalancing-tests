resource "aws_vpc" "flussonic_vpc" {
  cidr_block           = "10.2.0.0/16"
  enable_dns_hostnames = true
  tags = {
    Name      = "flussonic"
    Terraform = "true"
  }
}

resource "aws_subnet" "flussonic_subnet_ec2" {
  vpc_id            = aws_vpc.flussonic_vpc.id
  cidr_block        = "10.2.0.0/24"
  availability_zone = "us-west-2a"
  tags = {
    Name      = "flussonic_subnet_ec2"
    Terraform = "true"
  }
}

resource "aws_route_table_association" "flussonic_rt_assoc_subnet_ec2" {
  subnet_id      = aws_subnet.flussonic_subnet_ec2.id
  route_table_id = aws_route_table.flussonic_route_table.id
}

resource "aws_instance" "ingest_proxy" {
  instance_type               = "m6in.large"
  availability_zone           = "us-west-2a"
  subnet_id                   = aws_subnet.flussonic_subnet_ec2.id
  ami                         = "ami-0cd9cab99912ed28e"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.flussonic_sg_ec2.id]
  key_name                    = "flussonic"

  root_block_device {
    volume_size           = "20"
    volume_type           = "gp2"
    encrypted             = false
    delete_on_termination = true
  }

  tags = {
    Name      = "flussonic_ingest_proxy"
    Terraform = "true"
  }
}

resource "aws_instance" "ingest_cluster" {
  count                       = 1
  instance_type               = "m6in.large"
  availability_zone           = "us-west-2a"
  subnet_id                   = aws_subnet.flussonic_subnet_ec2.id
  ami                         = "ami-0cd9cab99912ed28e"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.flussonic_sg_ec2.id]
  key_name                    = "flussonic"

  root_block_device {
    volume_size           = "20"
    volume_type           = "gp2"
    encrypted             = false
    delete_on_termination = true
  }

  tags = {
    Name      = "flussonic_ingest_cluster_ec2_host${count.index}"
    Terraform = "true"
  }
}

resource "aws_instance" "edge_cluster" {
  count                       = 2
  instance_type               = "g3s.xlarge"
  availability_zone           = "us-west-2a"
  subnet_id                   = aws_subnet.flussonic_subnet_ec2.id
  ami                         = "ami-095413544ce52437d"
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.flussonic_sg_ec2.id]
  key_name                    = "flussonic"

  root_block_device {
    volume_size           = "20"
    volume_type           = "gp2"
    encrypted             = false
    delete_on_termination = true
  }

  tags = {
    Name      = "flussonic_edge_cluster_ec2_host${count.index}"
    Terraform = "true"
  }
}

resource "aws_security_group" "flussonic_sg_ec2" {
  vpc_id = aws_vpc.flussonic_vpc.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow ssh from any"
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow http from any"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow https from any"
  }

  ingress {
    from_port   = 1935
    to_port     = 1935
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow rtmp from any"
  }

  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow http from any"
  }

  ingress {
    cidr_blocks = ["0.0.0.0/0"]
    from_port   = 8
    to_port     = 0
    protocol    = "icmp"
    description = "Allow ping from any"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow out to any"
  }
}

resource "aws_internet_gateway" "flussonic_gw" {
  vpc_id = aws_vpc.flussonic_vpc.id
  tags = {
    Name      = "flussonic_gw"
    Terraform = "true"
  }
}

resource "aws_route_table" "flussonic_route_table" {
  vpc_id = aws_vpc.flussonic_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.flussonic_gw.id
  }

  tags = {
    Name      = "flussonic_route_table"
    Terraform = "true"
  }
}

resource "aws_eip" "ingest_proxy" {
  instance = aws_instance.ingest_proxy.id
  vpc      = true
}

resource "aws_route53_record" "ingest_proxy" {
  zone_id = var.system_dns_zone_id
  name    = "live.domain.test"
  type    = "A"
  ttl     = 300
  records = [aws_eip.ingest_proxy.public_ip]
}


resource "aws_route53_record" "edge-records" {
  count   = length(aws_instance.edge_cluster)
  zone_id = var.system_dns_zone_id
  name    = "${count.index}.play.domain.test"
  type    = "A"
  ttl     = 5
  records = [element(aws_instance.edge_cluster.*.public_ip, count.index)]
}

resource "aws_route53_record" "edge-weighted" {
  count          = length(aws_instance.edge_cluster)
  zone_id        = var.system_dns_zone_id
  name           = "play.domain.test"
  type           = "CNAME"
  ttl            = 5
  set_identifier = "-play-${count.index}"
  records        = ["${count.index}.play.domain.test"]

  weighted_routing_policy {
    weight = 10
  }
}

output "ingest_proxy_public_ip" {
  value       = aws_eip.ingest_proxy.public_ip
  description = "Ingest Proxy Public"
}

output "ingest_cluster_private_ips" {
  value       = ["${aws_instance.ingest_cluster.*.private_ip}"]
  description = "Ingest Cluster Private IPs"
}

output "ingest_cluster_public_ips" {
  value       = ["${aws_instance.ingest_cluster.*.public_ip}"]
  description = "Ingest Cluster Public IPs"
}

output "edge_cluster_private_ips" {
  value       = ["${aws_instance.edge_cluster.*.private_ip}"]
  description = "Edge Cluster Private IPs"
}

output "edge_cluster_public_ips" {
  value       = ["${aws_instance.edge_cluster.*.public_ip}"]
  description = "Edge Cluster Public IPs"
}

resource "local_file" "ansible_hosts" {
  content = templatefile("hosts.tmpl",
    {
      public_ip_ingest_proxy    = aws_instance.ingest_proxy.public_ip,
      public_ips_ingest_cluster = aws_instance.ingest_cluster.*.public_ip
      public_ips_edge_cluster   = aws_instance.edge_cluster.*.public_ip
    }
  )
  filename = "hosts"
}
