##############################################################################
# backend.tf
# MinIO — self-hosted S3-compatible remote state backend
##############################################################################

terraform {
  backend "s3" {
    # Static settings that never change between environments
    key    = "terraform-state/terraform.tfstate"
    region = "us-east-1" # MinIO default region. Do not change to 'auto' for MinIO!

    use_path_style              = true # Required for MinIO
    skip_credentials_validation = true
    skip_metadata_api_check     = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_s3_checksum            = true
  }
}
