#!/bin/bash
set -e

echo "Building Lambda deployment packages..."

# Package the producer Lambda
echo "Packaging producer Lambda..."
cd services/producer
mkdir -p layer/python
pip install -r requirements.txt -t ./layer/python --platform manylinux2014_x86_64 --only-binary=:all: --no-deps
cd layer
zip -r ../layer.zip python -x "*.pyc" "*.pyo" "*__pycache__*" "*.dist-info*" "*tests/*" "*/tests/*"
cd ..
zip lambda.zip app.py
rm -rf layer
cd ../..

# Package the processor Lambda
echo "Packaging processor Lambda..."
cd services/processor
mkdir -p layer/python
pip install -r requirements.txt -t ./layer/python --platform manylinux2014_x86_64 --only-binary=:all: --no-deps
cd layer
zip -r ../layer.zip python -x "*.pyc" "*.pyo" "*__pycache__*" "*.dist-info*" "*tests/*" "*/tests/*"
cd ..
zip lambda.zip app.py
rm -rf layer
cd ../..

# Navigate to the Terraform directory
cd infrastructure/terraform/environments/dev

# Initialize Terraform
echo "Initializing Terraform..."
terraform init

# Apply Terraform changes
echo "Applying Terraform changes..."
terraform apply -auto-approve

# Get Lambda function names from Terraform outputs
echo "Retrieving Lambda function names..."
PRODUCER_LAMBDA_NAME=$(terraform output -raw producer_lambda_function_name)
PROCESSOR_LAMBDA_NAME=$(terraform output -raw processor_lambda_function_name)

cd ../../../../..

# # Package and deploy the producer Lambda
# echo "Packaging and deploying producer Lambda..."
# cd services/producer
# pip install -r requirements.txt -t ./dist
# cp app.py ./dist
# cd dist
# zip -r ../producer.zip .
# cd ..
# aws lambda update-function-code --function-name $PRODUCER_LAMBDA_NAME --zip-file fileb://producer.zip
# rm -rf dist
# rm producer.zip
# cd ../..

# # Package and deploy the processor Lambda
# echo "Packaging and deploying processor Lambda..."
# cd services/processor
# pip install -r requirements.txt -t ./dist
# cp app.py ./dist
# cd dist
# zip -r ../processor.zip .
# cd ..
# aws lambda update-function-code --function-name $PROCESSOR_LAMBDA_NAME --zip-file fileb://processor.zip
# rm -rf dist
# rm processor.zip
# cd ../..

echo "Deployment completed successfully!"
