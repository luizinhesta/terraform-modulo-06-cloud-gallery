# -----------------------------------------------------------------------------
# s3.tf - Bucket PRIVADO do frontend e publicação dos arquivos
# -----------------------------------------------------------------------------

data "aws_caller_identity" "current" {}

locals {
  # Nome globalmente único: prefixo + conta + região.
  # Mudar este valor SUBSTITUI o bucket (o argumento "bucket" é ForceNew).
  bucket_prefix = "${var.project_name}-m06-${data.aws_caller_identity.current.account_id}-${var.aws_region}"
  frontend_name = local.bucket_prefix

  application_path = "${path.module}/../application"

  # Mapa extensão -> Content-Type. Sem isso o S3 serviria tudo como binário.
  content_types = {
    ".html" = "text/html; charset=utf-8"
    ".css"  = "text/css; charset=utf-8"
    ".js"   = "application/javascript; charset=utf-8"
    ".json" = "application/json; charset=utf-8"
    ".svg"  = "image/svg+xml"
    ".png"  = "image/png"
    ".jpg"  = "image/jpeg"
    ".webp" = "image/webp"
    ".ico"  = "image/x-icon"
    ".txt"  = "text/plain; charset=utf-8"
  }

  # fileset devolve um CONJUNTO com o caminho relativo de cada arquivo (index.html, css/style.css...).
  site_files = fileset(local.application_path, "**")
}

resource "aws_s3_bucket" "frontend" {
  bucket        = local.frontend_name
  force_destroy = true # permite o destroy do laboratório mesmo com objetos dentro

  tags = {
    Name       = "${local.frontend_name}"
    CostCenter = "laboratorio"
  }

  lifecycle {
    # ignore_changes: o Terraform deixa de comparar esta tag. Se alguém (ou uma
    # política da organização) mudar CostCenter fora do Terraform, o plan não
    # tenta desfazer. Útil para atributos gerenciados por outro processo.
    ignore_changes = [tags["CostCenter"]]

    # Exercício: para proteger o bucket, remova SOMENTE o "# " do início da linha
    # "prevent_destroy" logo abaixo. Não altere o texto dos comentários.
    # Com ele ativo, "terraform destroy" falha com "Instance cannot be destroyed".
    # Não fica ativo por padrão porque impediria destruir o laboratório; o valor
    # precisa ser literal (não aceita variável).
    # prevent_destroy = true
  }
}

# Bloqueia todo acesso público: leitura só via CloudFront (política do bucket).
resource "aws_s3_bucket_public_access_block" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# BucketOwnerEnforced desativa as ACLs: o acesso é controlado só por políticas.
resource "aws_s3_bucket_ownership_controls" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# Criptografia em repouso com chaves gerenciadas pelo S3 (SSE-S3), sem custo adicional.
resource "aws_s3_bucket_server_side_encryption_configuration" "frontend" {
  bucket = aws_s3_bucket.frontend.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

# Um aws_s3_object por arquivo da pasta application/ (for_each sobre o conjunto).
# Endereços: aws_s3_object.site["index.html"], aws_s3_object.site["images/cidade-01-noite.svg"]...
resource "aws_s3_object" "site" {
  for_each = local.site_files

  bucket = aws_s3_bucket.frontend.id
  key    = each.value
  source = "${local.application_path}/${each.value}"

  # Hash do conteúdo: se o arquivo mudar, o hash muda e o plan mostra "~ update in-place".
  source_hash = filemd5("${local.application_path}/${each.value}")

  content_type = lookup(
    local.content_types,
    try(regex("\\.[^.]+$", each.value), ""),
    "application/octet-stream"
  )

  depends_on = [aws_s3_bucket_server_side_encryption_configuration.frontend]
}
