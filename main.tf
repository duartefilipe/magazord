provider "aws" {
  region = "us-east-1"
}

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "subnet" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table" "routetable" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.subnet.id
  route_table_id = aws_route_table.routetable.id
}

resource "aws_security_group" "allow_ssh_http" {
  vpc_id = aws_vpc.main.id

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

  ingress {
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_ssh_http"
  }
}

resource "aws_instance" "web" {
  ami                    = "ami-0cf43e890af9e3351"
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.subnet.id
  vpc_security_group_ids = [aws_security_group.allow_ssh_http.id]
  associate_public_ip_address = true
  key_name               = "AWS-KEY"

  tags = {
    Name = "web-instance"
  }

  user_data = <<-EOF
                #!/bin/bash

                # Atualiza o sistema e instala o Docker
                sudo yum update -y
                sudo amazon-linux-extras install docker -y
                sudo systemctl start docker
                sudo systemctl enable docker
                sudo usermod -aG docker ec2-user

                # Instalação do PostgreSQL
                sudo yum install -y postgresql-server postgresql-contrib
                sudo postgresql-setup initdb

                # Configuração da autenticação do PostgreSQL para aceitar senhas
                sudo sed -i "s/ident/md5/" /var/lib/pgsql/data/pg_hba.conf
                sudo systemctl enable postgresql
                sudo systemctl start postgresql

                # Define a senha para o usuário postgres
                sudo -u postgres psql -c "ALTER USER postgres PASSWORD 'postgres';"

                # Instalação de dependências adicionais
                sudo yum install -y python3
                curl -O https://bootstrap.pypa.io/get-pip.py
                sudo python3 get-pip.py
                pip install boto3

                # Criação do arquivo index.php
                echo '<?php echo "Hello World"; ?>' > /home/ec2-user/index.php

                # Criação do Dockerfile com base no index.php
                echo 'FROM php:7.4-apache' > /home/ec2-user/Dockerfile
                echo 'COPY index.php /var/www/html/index.php' >> /home/ec2-user/Dockerfile

                # Construção da imagem Docker
                sudo docker build -t php-app /home/ec2-user

                # Execução do container Docker
                sudo docker run -d -p 80:80 --name php-app php-app

                # Subir o Jenkins em um container Docker
                sudo docker run -d -p 8081:8080 --name jenkins --restart unless-stopped jenkins/jenkins:lts

                echo "Docker, PostgreSQL, and Jenkins installation and configuration completed." | sudo tee /var/log/user-data.log
                EOF
}

resource "aws_s3_bucket" "backup_bucket" {
  bucket = "postgres-backups-bucket1"
  
  tags = {
    Name = "PostgresBackupsBucket1"
  }
}

output "instance_public_ip" {
  value = aws_instance.web.public_ip
}

output "backup_bucket_name" {
  value = aws_s3_bucket.backup_bucket.bucket
}
