# -----------------------------------------------------------------------------
# collections.tf - Tipos de coleção e expressões for (sem criar recursos)
#
# Tudo aqui é calculado já no plan e pode ser inspecionado com terraform console:
#   terraform console
#   > local.example_set
#   > local.images_by_category
#   > local.category_counts
# -----------------------------------------------------------------------------

locals {
  # ---- Os cinco tipos --------------------------------------------------------

  # list(string): ordenada, aceita repetição, acessada por ÍNDICE ([0], [1]...).
  # Um literal ["a", "b"] é, na verdade, uma TUPLE; tolist() fixa o tipo list(string).
  example_list = tolist(["a", "b", "a"])

  # set(string): SEM ordem e SEM repetição. toset() converte e descarta duplicados.
  # Resultado: ["a", "b"]. É o tipo que for_each aceita junto com map.
  example_set = toset(local.example_list)

  # map(string): chaves de texto, todos os valores do MESMO tipo. Acesso por CHAVE.
  example_map = tomap({ lab = "experimental", prd = "producao" })

  # object: atributos com nomes fixos e tipos DIFERENTES. É o "registro" do Terraform.
  example_object = { name = "galeria", images = 12, active = true }

  # tuple: lista cujo tipo muda a cada posição (texto, número, booleano).
  example_tuple = ["galeria", 12, true]

  # ATENÇÃO: for_each NÃO aceita list. Este trecho (comentado) falharia no plan:
  #   resource "aws_s3_bucket" "x" { for_each = local.example_list ... }
  # Corrija com toset(): for_each = toset(local.example_list)

  # ---- Expressões for sobre as imagens da galeria ---------------------------

  # 1) list -> list (filtrando com if): só os arquivos dentro de images/.
  #    local.site_files (s3.tf) é um SET vindo de fileset(); sort() exige uma lista.
  image_files = sort([for f in local.site_files : f if startswith(f, "images/")])

  # 2) list -> list de objetos: extrai a categoria do nome "categoria-NN-nome.svg".
  gallery_images = [
    for f in local.image_files : {
      file     = f
      category = split("-", basename(f))[0]
    }
  ]

  # 3) list -> map: arquivo => categoria.
  image_index = { for img in local.gallery_images : img.file => img.category }

  # 4) list -> map AGRUPADO: os três pontos (...) juntam as chaves repetidas em listas.
  #    Sem "...", duas imagens com a mesma categoria causariam erro de chave duplicada.
  images_by_category = { for img in local.gallery_images : img.category => img.file... }

  # 5) map -> map: quantas imagens há em cada categoria.
  category_counts = { for categoria, arquivos in local.images_by_category : categoria => length(arquivos) }

  # 6) map -> list: nomes das categorias em ordem alfabética.
  category_names = sort(keys(local.category_counts))

  # 7) filtro com if: apenas as imagens da categoria "cidade".
  city_images = [for img in local.gallery_images : img.file if img.category == "cidade"]
}