# Plan-only tests with a mocked provider: no AWS, no emulator.

mock_provider "aws" {
  mock_data "aws_region" {
    defaults = { region = "us-east-1" }
  }
  mock_data "aws_iam_policy_document" {
    defaults = { json = "{}" }
  }
}

variables {
  name = "test"
  cidr = "10.0.0.0/16"
  azs  = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

run "subnet_layout" {
  command = plan

  assert {
    condition     = output.subnet_cidrs.public == ["10.0.0.0/24", "10.0.1.0/24", "10.0.2.0/24"]
    error_message = "public subnets should be the first /24s"
  }
  assert {
    condition     = output.subnet_cidrs.private == ["10.0.16.0/20", "10.0.32.0/20", "10.0.48.0/20"]
    error_message = "private subnets should be /20s after the public block"
  }
  assert {
    condition     = output.subnet_cidrs.database == ["10.0.240.0/24", "10.0.241.0/24", "10.0.242.0/24"]
    error_message = "data subnets should sit at the top of the range"
  }
}

run "single_nat" {
  command = plan

  assert {
    condition     = length(output.nat_gateway_ids) == 1
    error_message = "single mode should create one NAT gateway"
  }
}

run "nat_per_az" {
  command = plan

  variables {
    nat_mode = "per_az"
  }

  assert {
    condition     = length(output.nat_gateway_ids) == 3
    error_message = "per_az mode should create one NAT gateway per AZ"
  }
}

run "gateway_endpoints" {
  command = plan

  assert {
    condition     = toset(keys(aws_vpc_endpoint.gateway)) == toset(["s3", "dynamodb"])
    error_message = "S3 and DynamoDB should have gateway endpoints"
  }
  assert {
    condition     = aws_vpc_endpoint.gateway["dynamodb"].service_name == "com.amazonaws.us-east-1.dynamodb"
    error_message = "endpoint service name should follow the region"
  }
}

run "flow_logs_off_by_default" {
  command = plan

  assert {
    condition     = output.flow_logs_log_group == null
    error_message = "no flow logs unless asked for"
  }
}

run "rejects_wrong_prefix" {
  command = plan

  variables {
    cidr = "10.0.0.0/20"
  }

  expect_failures = [var.cidr]
}
