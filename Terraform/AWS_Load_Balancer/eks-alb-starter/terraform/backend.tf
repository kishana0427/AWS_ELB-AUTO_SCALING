terraform {
  backend "s3" {
    bucket         = "my-eks-terraform-state"   # <-- change this to your S3 bucket name
    key            = "eks-cluster/terraform.tfstate"
    region         = "ap-south-1"               # <-- change region if needed
    dynamodb_table = "terraform-locks"          # <-- change this to your DynamoDB table name
    encrypt        = true
  }
}
