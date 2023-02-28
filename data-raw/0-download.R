# lista de assuntos -------------------------------------------------------
tabela <- stringr::str_c("https://esaj.tjsp.jus.br/cjpg/", tipo, "TreeSelect.do?campoId=", tipo) |> 
  httr::GET(httr::config(ssl_verifypeer = FALSE), lex:::esaj_ua()) |> 
  httr::content("text") |> 
  xml2::read_html() |> 
  xml2::xml_find_all("//div[@class='treeView']") |> 
  xml2::as_list() |> 
  dplyr::first() |> 
  dplyr::nth(2) |> 
  purrr::keep(~is.list(.x)) |> 
  lex:::tree_to_tibble() |> 
  dplyr::mutate(
    name0 = ifelse(is.na(name0), name5, name0), 
    id0 = ifelse(is.na(id0), id5, id0)
  ) |> 
  dplyr::select(
    dplyr::ends_with("0"), dplyr::ends_with("1"), 
    dplyr::ends_with("2"), dplyr::ends_with("3"), 
    dplyr::ends_with("4"), dplyr::ends_with("5")
  )

feminicidio <- tabela |>
  dplyr::filter(dplyr::if_any(
    dplyr::starts_with("name"),
    stringr::str_detect,
    pattern = stringr::regex("feminic", TRUE)
  ))

path_cjpg <- "data-raw/cjpg/"
path_cpopg <- "data-raw/cpopg/"

# download cjpg -----------------------------------------------------------
purrr::walk(feminicidio$id5, \(x) {
  usethis::ui_info(x)
  dir_assunto <- paste0(path_cjpg, x)
  fs::dir_create(dir_assunto)
  lex::tjsp_cjpg_download("", dir = dir_assunto, assunto = x)
})

# parse cjpg --------------------------------------------------------------
da_cjpg <- path_cjpg |>
  fs::dir_ls(
    type = "file",
    recurse = TRUE, regexp = "search", invert = TRUE
  ) |>
  purrr::map(lex::tjsp_cjpg_parse, .progress = TRUE) |>
  dplyr::bind_rows()

dplyr::glimpse(da_cjpg)

# download cpopg ----------------------------------------------------------
processos <- unique(da_cjpg$n_processo)
purrr::walk(
  processos,
  \(x) {Sys.sleep(1); lex::tjsp_cpopg_download(x, dir = path_cpopg)},
  .progress = TRUE
)

# parse cpopg -------------------------------------------------------------

da_cpopg <- fs::dir_ls(path_cpopg) |>
  purrr::map(lex::tjsp_cpopg_parse, .progress = TRUE) |>
  dplyr::bind_rows(.id = "file") |>
  dplyr::filter(!is.na(id_processo)) |>
  janitor::remove_empty("cols") |>
  dplyr::transmute(
    n_processo = tools::file_path_sans_ext(basename(file)),
    status, classe, assunto, foro, vara, juiz,
    distribuicao, digital, partes, movimentacoes
  )

da_cpopg_partes <- da_cpopg |>
  dplyr::select(n_processo, partes) |>
  tidyr::unnest(partes)

da_cpopg_movimentacoes <- da_cpopg |>
  dplyr::select(n_processo, movimentacoes) |>
  tidyr::unnest(movimentacoes)

da_cpopg_capa <- da_cpopg |>
  dplyr::select(-partes, -movimentacoes)


# export ------------------------------------------------------------------

readr::write_rds(da_cjpg, "data-raw/decisoes.rds")
readr::write_rds(da_cpopg_capa, "data-raw/capa.rds")
readr::write_rds(da_cpopg_partes, "data-raw/partes.rds")
readr::write_rds(da_cpopg_movimentacoes, "data-raw/movimentacoes.rds")

# upload ------------------------------------------------------------------

# piggyback::pb_new_release(tag= "atualizacao_20230228")
piggyback::pb_upload("data-raw/decisoes.rds", tag = "atualizacao_20230228")
piggyback::pb_upload("data-raw/capa.rds", tag = "atualizacao_20230228")
piggyback::pb_upload("data-raw/partes.rds", tag = "atualizacao_20230228")
piggyback::pb_upload("data-raw/movimentacoes.rds", tag = "atualizacao_20230228")

piggyback::pb_upload("data-raw/cjpg.zip", tag = "atualizacao_20230228")
piggyback::pb_upload("data-raw/cpopg.zip", tag = "atualizacao_20230228")


