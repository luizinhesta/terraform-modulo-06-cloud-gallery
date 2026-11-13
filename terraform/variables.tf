# variables.tf - entradas do módulo 06.

variable "aws_region" {
  description = "Região do bucket S3 (o endpoint REST regional é usado como origem do CloudFront)."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Prefixo dos nomes e valor da tag Project."
  type        = string
  default     = "tfpratica"

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,19}$", var.project_name))
    error_message = "project_name deve ter 3 a 20 caracteres: minúsculas, números e hífen, começando por letra."
  }
}

variable "environment" {
  description = "Ambiente (tag Environment)."
  type        = string
  default     = "lab"

  validation {
    condition     = contains(["lab", "dev", "hml", "prd"], var.environment)
    error_message = "environment deve ser lab, dev, hml ou prd."
  }
}

# ---- Variável de coleção (map de objetos) usada com for_each -----------------

variable "auxiliary_buckets" {
  description = "Buckets auxiliares. Chave = sufixo do nome; valor = finalidade e se o versionamento fica ligado."
  type = map(object({
    purpose    = string
    versioning = bool
  }))

  default = {
    "arquivos-extras" = {
      purpose    = "Arquivos extras de demonstração"
      versioning = false
    }
    "relatorios" = {
      purpose    = "Relatórios de demonstração (com versionamento)"
      versioning = true
    }
  }

  validation {
    condition     = alltrue([for k, _ in var.auxiliary_buckets : can(regex("^[a-z0-9][a-z0-9-]{1,20}$", k))])
    error_message = "As chaves de auxiliary_buckets devem ter 2 a 21 caracteres: minúsculas, números e hífen."
  }
}

# ---- Páginas de erro (map de objetos consumido por um bloco dynamic) ---------

variable "error_pages" {
  description = "Respostas de erro do CloudFront. Chave = código HTTP recebido da origem; valor = código devolvido e página exibida."

  type = map(object({
    response_code = number
    page_path     = string
    min_ttl       = optional(number, 10)
  }))

  # O S3 privado devolve 403 (e não 404) para chaves inexistentes; as duas viram a página 404.html.
  default = {
    "403" = { response_code = 404, page_path = "/404.html" }
    "404" = { response_code = 404, page_path = "/404.html" }
  }

  validation {
    condition     = alltrue([for codigo, _ in var.error_pages : can(tonumber(codigo))])
    error_message = "As chaves de error_pages devem ser códigos HTTP numéricos, como \"403\" e \"404\"."
  }
}
# ---- CloudFront --------------------------------------------------------------

variable "price_class" {
  description = "Classe de preço do CloudFront. PriceClass_100 usa só América do Norte e Europa (menor custo)."
  type        = string
  default     = "PriceClass_100"

  validation {
    condition     = contains(["PriceClass_100", "PriceClass_200", "PriceClass_All"], var.price_class)
    error_message = "price_class deve ser PriceClass_100, PriceClass_200 ou PriceClass_All."
  }
}

variable "enable_ipv6" {
  description = "Habilita IPv6 na distribuição (e cria o registro AAAA quando há domínio personalizado)."
  type        = bool
  default     = true
}

# ---- Domínio personalizado (opcional) ---------------------------------------

variable "enable_custom_domain" {
  description = "true = publica também em <subdomain>.<hosted_zone_name> usando Hosted Zone e certificado ACM JÁ existentes."
  type        = bool
  default     = false
}

variable "hosted_zone_name" {
  description = "Nome da Hosted Zone pública existente no Route 53 (ex.: exemplo.com.br)."
  type        = string
  default     = null
}

variable "subdomain" {
  description = "Rótulo do subdomínio deste módulo (ex.: galeria). Cada módulo usa o seu."
  type        = string
  default     = "galeria"

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?$", var.subdomain))
    error_message = "subdomain deve ser um único rótulo DNS (minúsculas, números e hífen)."
  }
}

variable "certificate_domain_name" {
  description = "Nome principal do certificado ACM emitido em us-east-1 (ex.: *.exemplo.com.br ou galeria.exemplo.com.br)."
  type        = string
  default     = null
}

variable "certificate_arn" {
  description = "Opcional. ARN do certificado (us-east-1). Se informado, dispensa a busca por certificate_domain_name no ACM."
  type        = string
  default     = null
}
