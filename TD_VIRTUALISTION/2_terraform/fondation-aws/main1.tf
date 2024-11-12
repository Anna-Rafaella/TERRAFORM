// Initialisation du provider AWS
provider "aws" {
  region = "eu-west-1"  // Exemple de région AWS, vous pouvez la changer
}

// Création de la ressource VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "my-vpc"
  }
}

// Création d'un sous-réseau dans le VPC
resource "aws_subnet" "my_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "eu-west-1a"

  tags = {
    Name = "my-subnet"
  }
}

// Création de la passerelle Internet pour le VPC
resource "aws_internet_gateway" "my_igw" {
  vpc_id = aws_vpc.my_vpc.id

  tags = {
    Name = "my-igw"
  }
}

// Ajout d'une route pour permettre l'accès Internet
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.my_igw.id
  }

  tags = {
    Name = "my-route-table"
  }
}

// Association de la route avec le sous-réseau
resource "aws_route_table_association" "my_route_table_assoc" {
  subnet_id      = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

// Ajout de plusieurs instances EC2 dans ce VPC
resource "aws_instance" "my_instance" {
  count         = 3  // Création de trois instances pour la haute disponibilité
  ami           = "ami-0c55b159cbfafe1f0"  // ID de l'AMI (exemple pour Debian)
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.my_subnet.id
  key_name      = "my-key"  // Remplacez par le nom de votre clé SSH

  // Bloc pour attacher un disque de démarrage
  root_block_device {
    volume_size = 8  // Taille du disque en Go
  }

  associate_public_ip_address = true  // Pour une IP publique sur chaque instance

  tags = {
    Name = "my-instance-${count.index}"
  }
}

// Ajout d'une base de données RDS dans ce VPC
resource "aws_db_instance" "my_rds_instance" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "12.4"
  instance_class       = "db.t2.micro"
  db_name              = "mydb"  // Remplacez `name` par `db_name`
  username             = "admin"
  password             = "adminpassword"  // Utilisez un mot de passe sécurisé
  publicly_accessible  = false
  skip_final_snapshot  = true
  vpc_security_group_ids = [aws_security_group.my_rds_sg.id]
  db_subnet_group_name = aws_db_subnet_group.my_db_subnet_group.name

  tags = {
    Name = "my-rds-instance"
  }
}

// Création d'un sous-réseau pour la base de données
resource "aws_db_subnet_group" "my_db_subnet_group" {
  name       = "my-db-subnet-group"
  subnet_ids = [aws_subnet.my_subnet.id]

  tags = {
    Name = "my-db-subnet-group"
  }
}

// Création du groupe de sécurité pour la base de données RDS
resource "aws_security_group" "my_rds_sg" {
  vpc_id = aws_vpc.my_vpc.id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  // Limité aux connexions internes au VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "my-rds-sg"
  }
}

// Ajout d'une entrée DNS avec Route 53
resource "aws_route53_zone" "my_dns_zone" {
  name = "example.com"
}

resource "aws_route53_record" "my_a_record" {
  zone_id = aws_route53_zone.my_dns_zone.zone_id
  name    = "www.example.com"
  type    = "A"
  ttl     = 300
  records = [aws_instance.my_instance[0].public_ip]
}
