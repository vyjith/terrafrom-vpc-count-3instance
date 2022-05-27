output "vpc_id" {

  value =   "The instance VPC ID is ${aws_vpc.main.id}"
}

output "public_subnet_ids" {
  
  value = [for name in aws_subnet.public-subnet[*].id: name]
}

output "private_subnet_ids" {

value = [for name in aws_subnet.private-subnet[*].id: name] 
}

output "ami" {

    value = "The latest ami of the amazon is ${data.aws_ami.latestami.id}"
  
}


output "public_webserver" {

    value = "The public ip address of the server is ${aws_instance.public.public_ip }"
}

output "public_ssh" {

    value = "The public ip address of the server is ${aws_instance.public-ssh.public_ip }"
}
