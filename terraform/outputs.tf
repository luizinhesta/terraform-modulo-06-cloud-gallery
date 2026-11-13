output "frontend_bucket_name" {
  description = "Bucket S3 privado com o frontend."
  value       = aws_s3_bucket.frontend.bucket
}

output "auxiliary_buckets" {
  description = "Buckets auxiliares (mapa chave => dados)."
  value = {
    for k, b in aws_s3_bucket.auxiliary : k => {
      name    = b.bucket
      arn     = b.arn
      purpose = var.auxiliary_buckets[k].purpose
    }
  }
}

output "cloudfront_distribution_id" {
  description = "ID da distribuição (usado em invalidações)."
  value       = aws_cloudfront_distribution.site.id
}

output "cloudfront_domain_name" {
  description = "Domínio *.cloudfront.net."
  value       = aws_cloudfront_distribution.site.domain_name
}

output "site_url" {
  description = "URL HTTPS padrão do CloudFront."
  value       = "https://${aws_cloudfront_distribution.site.domain_name}"
}

output "custom_url" {
  description = "URL do domínio personalizado (null se desabilitado)."
  value       = var.enable_custom_domain ? "https://${local.custom_fqdn}" : null
}

output "invalidation_command" {
  description = "Comando (NÃO executado) para limpar o cache após atualizar arquivos."
  value       = "aws cloudfront create-invalidation --distribution-id ${aws_cloudfront_distribution.site.id} --paths \"/*\""
}

# ---- Resultado das expressões for e dos tipos de coleção (collections.tf) ----

output "category_counts" {
  description = "Imagens por categoria (map -> map)."
  value       = local.category_counts
}

output "images_by_category" {
  description = "Arquivos agrupados por categoria (list -> map com agrupamento)."
  value       = local.images_by_category
}

output "collection_types_demo" {
  description = "Os cinco tipos de coleção lado a lado."
  value = {
    list   = local.example_list
    set    = local.example_set
    map    = local.example_map
    object = local.example_object
    tuple  = local.example_tuple
  }
}