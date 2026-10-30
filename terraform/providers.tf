provider "aws" {
  region = var.aws_region
}

# Sem account id (PR sem secrets) o provider recebe valores fictícios: ele só fala com o
# New Relic quando algum recurso newrelic_* existe. Key ausente com a integração ligada
# cai na precondition do vínculo (newrelic.tf).
provider "newrelic" {
  account_id = local.newrelic_enabled == 1 ? tonumber(trimspace(var.newrelic_account_id)) : 0
  api_key    = coalesce(var.newrelic_api_key, "disabled")
  region     = var.newrelic_region
}
