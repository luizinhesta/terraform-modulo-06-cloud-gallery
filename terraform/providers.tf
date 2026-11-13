# providers.tf
# Credenciais vêm do perfil do AWS CLI (AWS_PROFILE). Nunca escreva chaves aqui.

# Provider padrão: S3 e Route 53 (a API do Route 53 é global).
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      Module      = "modulo-06-cloud-gallery"
      ManagedBy   = "terraform"
    }
  }
}

# Provider com ALIAS fixo em us-east-1.
# Certificados ACM usados pelo CloudFront só valem se estiverem em us-east-1,
# mesmo que o bucket esteja em outra região. Os data sources de certificado
# usam este provider com: provider = aws.us_east_1
provider "aws" {
  alias  = "us_east_1"
  region = "us-east-1"
}
