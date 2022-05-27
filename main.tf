resource "aws_vpc" "main" {


    cidr_block = var.cidr
    instance_tenancy = "default"
    enable_dns_hostnames = true
    enable_dns_support = true

    tags = {
      Name = var.project
      project = "newsetup"
    }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "${var.project}-igw"
  }
}

resource "aws_subnet" "public-subnet" {

  count = 3
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(var.cidr, 3, count.index)
  availability_zone = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project}-public${count.index+1}"
  }
}

resource "aws_subnet" "private-subnet" {

    count = 3
    vpc_id     = aws_vpc.main.id
    cidr_block = cidrsubnet(var.cidr, 3, (count.index+3))
    availability_zone = data.aws_availability_zones.available.names[count.index]
    tags = {
      "Name" = "${var.project}-private${count.index+1}"
    }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = {
    "Name" = "${var.project}-public-rtb"
  }
}


resource "aws_eip" "elastic" {
  vpc      = true
}

resource "aws_nat_gateway" "natgat" {
  allocation_id = aws_eip.elastic.id
  subnet_id     = aws_subnet.public-subnet[1].id

  tags = {
    Name = "${var.project}-private-NAT"
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_nat_gateway.natgat.id
  }
tags = {

    Name = "${var.project}-private-rtb"
}

}
resource "aws_route_table_association" "public" {

count = 3

  subnet_id      = aws_subnet.public-subnet[count.index].id
  route_table_id = aws_route_table.public.id

  depends_on = [
    aws_subnet.public-subnet
  ]
}

resource "aws_route_table_association" "private" {

count = 3

  subnet_id      = aws_subnet.private-subnet[count.index].id
  route_table_id = aws_route_table.private.id

  depends_on = [
    aws_subnet.private-subnet
  ]
}

resource "aws_key_pair" "newkey" {
  key_name   = "${var.project}-key"
  public_key = file("vyjith.pub")

  tags = {
    "Name" = "${var.project}-key"
  }

}
resource "aws_security_group" "allow_webserver" {
  name        = "allow_tls"
  description = "Allow from all traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = ""
    from_port        = 443
    to_port          = 443
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
  ingress {
    description      = ""
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  ingress {
    description      = ""
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups = [ aws_security_group.allow_ssh.id ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project}webserver-sg"
  }
}

resource "aws_security_group" "allow_ssh" {
  name        = "allow_ssh"
  description = "Allow from all traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = ""
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project}ssh-sg"
  }
}

resource "aws_security_group" "allow_backend" {
  name        = "allow_backend"
  description = "Allow from all traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = ""
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    security_groups = [ aws_security_group.allow_ssh.id ]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "${var.project}private-sg"
  }
}

resource "aws_instance" "public" {
  ami           = data.aws_ami.latestami.id
  instance_type = "t2.micro"
  user_data = file("setup.sh")
  key_name = aws_key_pair.newkey.id
  vpc_security_group_ids = [ aws_security_group.allow_webserver.id ]
  subnet_id = aws_subnet.public-subnet[1].id


  tags = {
    "Name" = "${var.project}-webserver"
  }

}

resource "aws_instance" "public-ssh" {
  ami           = data.aws_ami.latestami.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.newkey.id
  vpc_security_group_ids = [ aws_security_group.allow_ssh.id ]
  subnet_id = aws_subnet.public-subnet[0].id

  tags = {
    "Name" = "${var.project}-ssh"
  }

}

resource "aws_instance" "backend" {
  ami           = data.aws_ami.latestami.id
  instance_type = "t2.micro"
  key_name = aws_key_pair.newkey.id
  vpc_security_group_ids = [ aws_security_group.allow_backend.id ]
  subnet_id = aws_subnet.private-subnet[0].id

  tags = {
    "Name" = "${var.project}-backend"
  }

}
