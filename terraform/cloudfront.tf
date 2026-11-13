# -----------------------------------------------------------------------------
# cloudfront.tf - OAC, distribuição e política do bucket
#
# Ordem real de criação (o Terraform descobre pelas referências):
#
#   aws_s3_bucket.frontend ──┐
#   aws_cloudfront_origin_access_control.site ──┴─> aws_cloudfront_distribution.site
#                                                        │ (ARN conhecido só após criar)
#                                                        v
#                                             aws_s3_bucket_policy.frontend
# -----------------------------------------------------------------------------

# Política de cache gerenciada pela AWS, buscada pelo NOME (sem IDs fixos no código).
data "aws_cloudfront_cache_policy" "caching_optimized" {
  name = "Managed-CachingOptimized"
}

# OAC: faz o CloudFront ASSINAR (SigV4) as requisições ao S3. Sem custo.
# Não usa create_before_destroy: o nome do OAC é único na conta e o novo
# conflitaria com o antigo durante a troca.
resource "aws_cloudfront_origin_access_control" "site" {
  name                              = "${var.project_name}-m06-oac"
  description                       = "OAC da Cloud Gallery (modulo 06)"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

locals {
  custom_aliases = var.enable_custom_domain ? [local.custom_fqdn] : []
}

resource "aws_cloudfront_distribution" "site" {
  enabled             = true
  comment             = "Terraform na Pratica - Modulo 06 - Cloud Gallery"
  default_root_object = "index.html"
  price_class         = var.price_class
  is_ipv6_enabled     = var.enable_ipv6
  http_version        = "http2"

  # Domínios alternativos (CNAMEs). Lista vazia quando o domínio personalizado está desligado.
  aliases = local.custom_aliases

  origin {
    origin_id = "s3-frontend"

    # Endpoint REGIONAL REST do bucket (nome.s3.<região>.amazonaws.com).
    # NÃO é o endpoint de website: o OAC só funciona com o endpoint REST.
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.site.id
  }

  default_cache_behavior {
    target_origin_id       = "s3-frontend"
    viewer_protocol_policy = "redirect-to-https"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    compress               = true
    cache_policy_id        = data.aws_cloudfront_cache_policy.caching_optimized.id
  }

  # dynamic gera UM bloco custom_error_response para CADA elemento de var.error_pages.
  # Dentro de content, o "iterador" tem o nome do bloco:
  #   custom_error_response.key   = "403" / "404"  (chave do mapa)
  #   custom_error_response.value = objeto { response_code, page_path, min_ttl }
  # Adicionar uma entrada no mapa cria mais um bloco, sem copiar e colar código.
  dynamic "custom_error_response" {
    for_each = var.error_pages

    content {
      error_code            = tonumber(custom_error_response.key)
      response_code         = custom_error_response.value.response_code
      response_page_path    = custom_error_response.value.page_path
      error_caching_min_ttl = custom_error_response.value.min_ttl
    }
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Padrão "interruptor": dynamic com lista de 0 ou 1 elemento liga ou desliga um bloco.
  # Sem domínio: certificado padrão *.cloudfront.net.
  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain ? [] : [1]
    content {
      cloudfront_default_certificate = true
    }
  }

  # Com domínio: certificado ACM existente (us-east-1) via SNI (sem custo de IP dedicado).
  dynamic "viewer_certificate" {
    for_each = var.enable_custom_domain ? [1] : []
    content {
      acm_certificate_arn      = local.certificate_arn
      ssl_support_method       = "sni-only"
      minimum_protocol_version = "TLSv1.2_2021"
    }
  }

  tags = {
    Name = "${var.project_name}-m06-cloudfront"
  }

  lifecycle {
    precondition {
      condition     = !var.enable_custom_domain || (var.hosted_zone_name != null && var.certificate_domain_name != null)
      error_message = "Com enable_custom_domain = true, informe hosted_zone_name e certificate_domain_name."
    }

    precondition {
      condition     = !var.enable_custom_domain || local.certificate_region == "us-east-1"
      error_message = "O certificado do CloudFront precisa estar em us-east-1. Região encontrada: ${coalesce(local.certificate_region, "desconhecida")}."
    }

    precondition {
      condition     = !var.enable_custom_domain || local.certificate_covers_fqdn
      error_message = "O certificado '${coalesce(var.certificate_domain_name, "")}' não cobre ${coalesce(local.custom_fqdn, "o domínio")}. Use o nome exato ou um curinga de um nível (*.dominio)."
    }
  }
}

# Política do bucket: só ESTA distribuição pode ler objetos (s3:GetObject).
# Não há ListBucket: chave inexistente => 403 (tratado pelo custom_error_response).
data "aws_iam_policy_document" "frontend" {
  statement {
    sid       = "PermitirLeituraSomenteDoCloudFront"
    effect    = "Allow"
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.frontend.arn}/*"]

    principals {
      type        = "Service"
      identifiers = ["cloudfront.amazonaws.com"]
    }

    condition {
      test     = "StringEquals"
      variable = "AWS:SourceArn"
      # Atributo computado: o ARN só existe depois que a distribuição é criada.
      values = [aws_cloudfront_distribution.site.arn]
    }
  }
}

resource "aws_s3_bucket_policy" "frontend" {
  bucket = aws_s3_bucket.frontend.id
  policy = data.aws_iam_policy_document.frontend.json

  # A AWS rejeita alterações simultâneas no mesmo bucket (OperationAborted).
  # Os dois recursos não se referenciam, então a ordem é imposta aqui.
  depends_on = [aws_s3_bucket_public_access_block.frontend]
}
