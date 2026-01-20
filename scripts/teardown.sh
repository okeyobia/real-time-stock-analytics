#!/bin/bash
set -e

# Navigate to the Terraform directory
cd infrastructure/terraform/environments/dev

# Destroy Terraform-managed infrastructure
echo "Destroying Terraform-managed infrastructure..."
terraform destroy -auto-approve

echo "Teardown completed successfully!"
