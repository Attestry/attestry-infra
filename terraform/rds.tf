resource "random_password" "rds_master" {
  length           = 24
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "aws_db_subnet_group" "attestry" {
  name       = "attestry-dev-db-subnet-group"
  subnet_ids = module.vpc.database_subnets

  tags = {
    Name        = "attestry-dev-db-subnet-group"
    Environment = "dev"
    Project     = "attestry"
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "rds" {
  name        = "attestry-dev-rds-sg"
  description = "Allow PostgreSQL from EKS worker nodes"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description     = "PostgreSQL from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [module.eks.node_security_group_id]
  }

  ingress {
    description = "PostgreSQL from dev team"
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = [
      "211.60.161.245/32",
      "61.43.122.41/32",
      "193.186.4.167/32",
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "attestry-dev-rds-sg"
    Environment = "dev"
    Project     = "attestry"
    ManagedBy   = "terraform"
  }
}

resource "aws_db_instance" "postgres" {
  identifier              = "attestry-dev-postgres"
  engine                  = "postgres"
  engine_version          = "16.10"
  instance_class          = "db.t4g.medium"
  allocated_storage       = 50
  max_allocated_storage   = 200
  storage_type            = "gp3"
  storage_encrypted       = true
  port                    = 5432
  db_name                 = "attestry_dev"
  username                = "attestry_admin"
  password                = random_password.rds_master.result
  db_subnet_group_name    = aws_db_subnet_group.attestry.name
  vpc_security_group_ids  = [aws_security_group.rds.id]
  backup_retention_period = 7
  backup_window           = "18:00-19:00"
  maintenance_window      = "sun:19:00-sun:20:00"
  multi_az                = false
  publicly_accessible     = true
  deletion_protection     = false
  skip_final_snapshot     = true
  apply_immediately       = true

  tags = {
    Name        = "attestry-dev-postgres"
    Environment = "dev"
    Project     = "attestry"
    ManagedBy   = "terraform"
  }
}
