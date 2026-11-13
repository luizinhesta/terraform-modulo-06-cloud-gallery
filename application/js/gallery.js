"use strict";

// Catálogo da galeria. Os arquivos ficam em images/ e são enviados ao S3 pelo Terraform.
const IMAGENS = [
  { arquivo: "natureza-01-amanhecer.svg", titulo: "Amanhecer nas montanhas", categoria: "natureza" },
  { arquivo: "natureza-02-entardecer.svg", titulo: "Entardecer nas colinas", categoria: "natureza" },
  { arquivo: "natureza-03-vale.svg", titulo: "Vale verde", categoria: "natureza" },
  { arquivo: "cidade-01-noite.svg", titulo: "Cidade à noite", categoria: "cidade" },
  { arquivo: "cidade-02-madrugada.svg", titulo: "Cidade na madrugada", categoria: "cidade" },
  { arquivo: "cidade-03-por-do-sol.svg", titulo: "Cidade ao pôr do sol", categoria: "cidade" },
  { arquivo: "abstrato-01-circulos.svg", titulo: "Círculos translúcidos", categoria: "abstrato" },
  { arquivo: "abstrato-02-aurora.svg", titulo: "Aurora abstrata", categoria: "abstrato" },
  { arquivo: "abstrato-03-calor.svg", titulo: "Tons quentes", categoria: "abstrato" },
  { arquivo: "tecnologia-01-rede.svg", titulo: "Rede de nós", categoria: "tecnologia" },
  { arquivo: "tecnologia-02-grafo.svg", titulo: "Grafo de dependências", categoria: "tecnologia" },
  { arquivo: "tecnologia-03-nuvem.svg", titulo: "Malha da nuvem", categoria: "tecnologia" },
];

const estado = { categoria: "todas", busca: "" };

const elGaleria = document.getElementById("galeria");
const elFiltros = document.getElementById("filtros");
const elBusca = document.getElementById("busca");
const elContagem = document.getElementById("contagem");
const elDialogo = document.getElementById("visualizador");

function criarFiltros() {
  const categorias = ["todas", ...new Set(IMAGENS.map((i) => i.categoria))];
  for (const categoria of categorias) {
    const botao = document.createElement("button");
    botao.type = "button";
    botao.textContent = categoria.charAt(0).toUpperCase() + categoria.slice(1);
    botao.dataset.categoria = categoria;
    botao.addEventListener("click", () => {
      estado.categoria = categoria;
      renderizar();
    });
    elFiltros.append(botao);
  }
}

function abrir(imagem) {
  document.getElementById("visualizador-titulo").textContent = imagem.titulo;
  const img = document.getElementById("visualizador-imagem");
  img.src = "images/" + imagem.arquivo;
  img.alt = imagem.titulo;
  elDialogo.showModal();
}

function renderizar() {
  for (const botao of elFiltros.children) {
    botao.setAttribute("aria-pressed", String(botao.dataset.categoria === estado.categoria));
  }

  const termo = estado.busca.trim().toLowerCase();
  const visiveis = IMAGENS.filter(
    (i) =>
      (estado.categoria === "todas" || i.categoria === estado.categoria) &&
      i.titulo.toLowerCase().includes(termo)
  );

  elGaleria.replaceChildren();
  for (const imagem of visiveis) {
    const li = document.createElement("li");
    const botao = document.createElement("button");
    botao.type = "button";
    botao.setAttribute("aria-label", "Ampliar: " + imagem.titulo);

    const img = document.createElement("img");
    img.src = "images/" + imagem.arquivo;
    img.alt = imagem.titulo;
    img.loading = "lazy";

    const legenda = document.createElement("span");
    legenda.className = "legenda";
    legenda.textContent = imagem.titulo;
    const categoria = document.createElement("span");
    categoria.className = "categoria";
    categoria.textContent = imagem.categoria;
    legenda.append(categoria);

    botao.append(img, legenda);
    botao.addEventListener("click", () => abrir(imagem));
    li.append(botao);
    elGaleria.append(li);
  }

  elContagem.textContent = visiveis.length + " de " + IMAGENS.length + " imagens";
}

elBusca.addEventListener("input", () => {
  estado.busca = elBusca.value;
  renderizar();
});

document.getElementById("protocolo").textContent = location.protocol.replace(":", "").toUpperCase();
document.getElementById("origem").textContent = location.host;

criarFiltros();
renderizar();
