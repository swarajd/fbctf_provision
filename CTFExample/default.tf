provider "aws" {
  region     = "us-east-1"
}

resource "aws_security_group" "allow_sshttp" {
  name        = "allow_sshttp"
  description = "Allow all sshttp traffic"

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

}

resource "aws_instance" "example" {
  ami           = "ami-a4c7edb2"
  instance_type = "t2.micro"
  key_name      = "terra-test"

  security_groups = [
    "${aws_security_group.allow_sshttp.name}"
  ]

  tags {
    ChallengeName = "ctfexample"
    Hostname      = "testttt"
  }

  root_block_device {
    delete_on_termination = true
    volume_size           = 8
  }

  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      user        = "ec2-user"
      password    = "root"
      private_key = "${file("../key.pem")}"
    }

    inline = [
      # create the dir structure for docker
      "mkdir /home/ec2-user/web/",

      # install docker
      "sudo yum install -y docker",
      "sudo service docker start",
      "sudo usermod -a -G docker ec2-user",
      "sudo docker pull richarvey/nginx-php-fpm",
    ]
  }

  provisioner "file" {

    connection {
      type        = "ssh"
      user        = "ec2-user"
      password    = "root"
      private_key = "${file("../key.pem")}"
    }

    source="web/"
    destination="/home/ec2-user/web/"
  }

  provisioner "file" {

    connection {
      type        = "ssh"
      user        = "ec2-user"
      password    = "root"
      private_key = "${file("../key.pem")}"
    }

    source="../Dockerfile"
    destination="/home/ec2-user/Dockerfile"
  }

  provisioner "remote-exec" {

    connection {
      type        = "ssh"
      user        = "ec2-user"
      password    = "root"
      private_key = "${file("../key.pem")}"
    }

    inline = [
      "docker build -t ${aws_instance.example.tags.ChallengeName} .",
      "docker run -d -p 80:80 --hostname ${aws_instance.example.tags.Hostname} ${aws_instance.example.tags.ChallengeName}"
    ]
  }

}

resource "null_resource" "reprovision" {
  triggers {
    rerun = "${uuid()}"
  }

  connection {
    type        = "ssh"
    user        = "ec2-user"
    password    = "root"
    private_key = "${file("../key.pem")}"
    host        = "${aws_instance.example.public_ip}"
  }

  provisioner "file" {
    source="web/"
    destination="/home/ec2-user/web/"
  }

  provisioner "remote-exec" {
     inline = [
      "docker stop $(docker ps -aq)",
      "docker rm $(docker ps -aq)",
      "docker build -t ${aws_instance.example.tags.ChallengeName} .",
      "docker run -d -p 80:80 --hostname ${aws_instance.example.tags.Hostname} ${aws_instance.example.tags.ChallengeName}"
    ]
  }

}
