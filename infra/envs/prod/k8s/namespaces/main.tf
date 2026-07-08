module "namespaces" {
  source = "../../../../modules/namespaces"

  # database:    namespace do cluster CNPG dedicado controlcar-postgres (Phase 9).
  # cnpg-system: namespace do CNPG operator (reativado no 09-01).
  # helm-stack usa create_namespace=false, então precisam ser criados aqui.
  extra_namespaces = ["database", "cnpg-system"]
}
