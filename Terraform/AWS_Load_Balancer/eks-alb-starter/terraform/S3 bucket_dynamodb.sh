#Create an S3 bucket (must exist before running terraform init):
aws s3api create-bucket --bucket my-eks-terraform-state --region ap-south-1


aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region ap-south-1
