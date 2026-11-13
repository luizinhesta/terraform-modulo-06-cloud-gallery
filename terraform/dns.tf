# -----------------------------------------------------------------------------
# dns.tf - Domínio personalizado OPCIONAL (Route 53 + ACM já existentes)
#
# Nada aqui cria Hosted Zone, domínio ou certificado: tudo é LIDO com data sources.
# Com enable_custom_domain = false, nenhum recurso/data deste arquivo é criado (count = 0).
# -----------------------------------------------------------------------------

locals {
  custom_fqdn = var.enable_custom_domain && var.hosted_zone_name != null ? "${var.subdomain}.${var.hosted_zone_name}" : null
}

# Hosted Zone pública existente.
data "aws_route53_zone" "existing" {
  count = var.enable_custom_domain ? 1 : 0

  name         = var.hosted_zone_name
  private_zone = false
}

# Certificado existente, buscado pelo nome principal e somente se estiver ISSUED.
# provider = aws.us_east_1 garante a região exigida pelo CloudFront.
# Pulado se você informou certificate_arn diretamente.
data "aws_acm_certificate" "existing" {
  provider = aws.us_east_1
  count    = var.enable_custom_domain && var.certificate_arn == null ? 1 : 0

  domain      = var.certificate_domain_name
  statuses    = ["ISSUED"]
  most_recent = true
}

locals {
  certificate_arn = !var.enable_custom_domain ? null : (
    var.certificate_arn != null ? var.certificate_arn : data.aws_acm_certificate.existing[0].arn
  )

  # ARN: arn:aws:acm:<região>:<conta>:certificate/<id> -> o 4º campo é a região.
  certificate_region = local.certificate_arn == null ? null : element(split(":", local.certificate_arn), 3)

  # Primeiro rótulo substituído por *: galeria.exemplo.com.br -> *.exemplo.com.br
  wildcard_of_fqdn = local.custom_fqdn == null ? null : "*.${join(".", slice(split(".", local.custom_fqdn), 1, length(split(".", local.custom_fqdn))))}"

  # O certificado cobre o nome se for igual ao FQDN ou ao curinga de UM nível.
  certificate_covers_fqdn = local.custom_fqdn != null && var.certificate_domain_name != null && contains(
    [local.custom_fqdn, local.wildcard_of_fqdn],
    lower(var.certificate_domain_name)
  )
}

# Alias A (IPv4) apontando para a distribuição. allow_overwrite = false:
# se o nome já existir (outro projeto), o apply FALHA em vez de sobrescrever.
resource "aws_route53_record" "alias_a" {
  count = var.enable_custom_domain ? 1 : 0

  zone_id         = data.aws_route53_zone.existing[0].zone_id
  name            = local.custom_fqdn
  type            = "A"
  allow_overwrite = false

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}

# Alias AAAA (IPv6), somente se o IPv6 estiver habilitado na distribuição.
resource "aws_route53_record" "alias_aaaa" {
  count = var.enable_custom_domain && var.enable_ipv6 ? 1 : 0

  zone_id         = data.aws_route53_zone.existing[0].zone_id
  name            = local.custom_fqdn
  type            = "AAAA"
  allow_overwrite = false

  alias {
    name                   = aws_cloudfront_distribution.site.domain_name
    zone_id                = aws_cloudfront_distribution.site.hosted_zone_id
    evaluate_target_health = false
  }
}
