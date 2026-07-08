module "namespaces" {
  source = "../../../../modules/namespaces"

  # database: namespace do cluster CNPG dedicado controlcar-postgres (Phase 9).
  # helm-stack usa create_namespace=false, então precisa ser criado aqui.
  extra_namespaces = ["database"]
}
