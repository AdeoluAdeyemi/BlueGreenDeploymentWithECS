# Create a S3 bucket

resource "aws_s3_bucket" "example" {
  bucket = "my-tf-test-bucket"

  tags = {
    Name        = "My bucket"
    Environment = "Dev"
  }
}


resource "aws_vpc_endpoint" "s3" {
  vpc_id       = aws_vpc.main.id
  service_name = "com.amazonaws.us-west-2.s3"

  tags = {
    Environment = "test"
  }
}


data "aws_caller_identity" "current" {}

resource "aws_vpc_endpoint_service" "example" {
  acceptance_required        = false
  allowed_principals         = [data.aws_caller_identity.current.arn]
  gateway_load_balancer_arns = [aws_lb.example.arn]
}

resource "aws_vpc_endpoint" "example" {
  service_name      = aws_vpc_endpoint_service.example.service_name
  subnet_ids        = [aws_subnet.example.id]
  vpc_endpoint_type = aws_vpc_endpoint_service.example.service_type
  vpc_id            = aws_vpc.example.id
}

resource "aws_vpc_endpoint_route_table_association" "example" {
  route_table_id  = aws_route_table.example.id
  vpc_endpoint_id = aws_vpc_endpoint.example.id
}

data "aws_vpc_endpoint_service" "example" {
  service = "dynamodb"
}

resource "aws_vpc" "example" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_vpc_endpoint" "example" {
  service_name = data.aws_vpc_endpoint_service.example.service_name
  vpc_id       = aws_vpc.example.id
}

resource "aws_vpc_endpoint_policy" "example" {
  vpc_endpoint_id = aws_vpc_endpoint.example.id
  policy = jsonencode({
    "Version" : "2012-10-17",
    "Statement" : [
      {
        "Sid" : "AllowAll",
        "Effect" : "Allow",
        "Principal" : {
          "AWS" : "*"
        },
        "Action" : [
          "dynamodb:*"
        ],
        "Resource" : "*"
      }
    ]
  })
}

resource "aws_vpc_endpoint_subnet_association" "sn_ec2" {
  vpc_endpoint_id = aws_vpc_endpoint.ec2.id
  subnet_id       = aws_subnet.sn.id
}