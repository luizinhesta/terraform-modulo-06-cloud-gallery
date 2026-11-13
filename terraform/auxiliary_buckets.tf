# -----------------------------------------------------------------------------
# auxiliary_buckets.tf - Recursos dinâmicos: for_each, each.key, each.value, count
#
# Os buckets auxiliares NÃO são usados pela aplicação. Existem para estudar como o
# Terraform multiplica recursos a partir de uma variável de coleção.
# -----------------------------------------------------------------------------

# for_each sobre um MAP: uma instância por chave.
#   each.key   = "arquivos-extras" / "relatorios"
#   each.value = o objeto { purpose, versioning }
# Endereços no state: aws_s3_bucket.auxiliary["relatorios"]
#
# Se você ADICIONAR uma chave em var.auxiliary_buckets  -> o plan cria só o bucket novo.
# Se REMOVER uma chave                                  -> o plan destrói só o bucket dela.
# As demais instâncias não mudam, porque são identificadas pela CHAVE.
resource "aws_s3_bucket" "auxiliary" {
  for_each = var.auxiliary_buckets

  bucket        = "${local.bucket_prefix}-${each.key}"
  force_destroy = true

  tags = {
    Name    = "${local.bucket_prefix}-${each.key}"
    Purpose = each.value.purpose
  }


  lifecycle {
    # O prefixo inclui conta e região; uma chave longa pode ultrapassar o limite de 63
    # caracteres do S3. O validate não enxerga isso (depende de data source), o plan sim.
    precondition {
      condition     = length("${local.bucket_prefix}-${each.key}") <= 63
      error_message = "O nome '${local.bucket_prefix}-${each.key}' tem mais de 63 caracteres. Use uma chave de auxiliary_buckets ou um project_name menor."
    }
  }
}

# for_each sobre OUTRO recurso: itera sobre o mapa de buckets criado acima.
# Aqui each.key é a mesma chave e each.value é o objeto do bucket (com id, arn...).
resource "aws_s3_bucket_public_access_block" "auxiliary" {
  for_each = aws_s3_bucket.auxiliary

  bucket = each.value.id

  block_public_acls       = true
  ignore_public_acls      = true
  block_public_policy     = true
  restrict_public_buckets = true
}

# Condicional dentro do for_each: o filtro "if v.versioning" deixa no mapa só os
# buckets com versionamento ligado. Com os valores padrão, só "relatorios".
resource "aws_s3_bucket_versioning" "auxiliary" {
  for_each = { for k, v in var.auxiliary_buckets : k => v if v.versioning }

  bucket = aws_s3_bucket.auxiliary[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

locals {
  # Lista ORDENADA das chaves: ["arquivos-extras", "relatorios"].
  auxiliary_keys = sort(keys(var.auxiliary_buckets))
}

# count sobre uma LISTA: instâncias identificadas por ÍNDICE (count.index = 0, 1...).
# Endereços: aws_s3_object.auxiliary_readme[0] e aws_s3_object.auxiliary_readme[1].
#
# ATENÇÃO (diferença para for_each): se você remover "arquivos-extras", a lista
# passa a ser ["relatorios"] e o objeto do bucket "relatorios" muda de índice
# [1] -> [0]. O Terraform enxerga isso como alteração/recriação de instâncias por
# causa do deslocamento, não apenas "remover o item que saiu".
resource "aws_s3_object" "auxiliary_readme" {
  count = length(local.auxiliary_keys)

  bucket       = aws_s3_bucket.auxiliary[local.auxiliary_keys[count.index]].id
  key          = "LEIA-ME.txt"
  content      = "Bucket auxiliar '${local.auxiliary_keys[count.index]}' do modulo 06. Gerenciado pelo Terraform.\n"
  content_type = "text/plain; charset=utf-8"

  # create_before_destroy = true   <- EXEMPLO DE USO ERRADO (não ativado).
  # Ele cria o substituto ANTES de apagar o antigo. Aqui o novo e o antigo teriam a
  # MESMA chave ("LEIA-ME.txt") no mesmo bucket: o apagamento do antigo removeria o novo.
  # Use-o quando o substituto pode coexistir com o original (ex.: Security Group com
  # name_prefix, no módulo 05). Para ativar, ele precisaria estar dentro de um bloco lifecycle {}.
}
