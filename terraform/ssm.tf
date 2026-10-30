# Contrato com os outros repositórios. Quem consome lê estes parâmetros (Terraform:
# data "aws_ssm_parameter"; workflows: aws ssm get-parameter) e falha se não existirem.
# Renomear ou remover um parâmetro é uma mudança de contrato: ver README.md.
#
# Consumidores:
#   network/*        -> tech-challenge-infra-db, tech-challenge-lambda
#   eks/*            -> tech-challenge-infra-db (ingress do RDS), tech-chalange (kubeconfig)
#   ecr/*            -> tech-chalange (push da imagem)
#   apigw/*          -> tech-challenge-lambda (rota POST /autenticacao)
#   observability/*  -> tech-challenge-lambda (logs para o New Relic; só com New Relic ligado)

locals {
  ssm_parameters = merge(
    {
      "network/vpc_id"                = aws_vpc.this.id
      "network/private_subnet_ids"    = join(",", aws_subnet.private[*].id)
      "network/public_subnet_ids"     = join(",", aws_subnet.public[*].id)
      "eks/cluster_name"              = aws_eks_cluster.this.name
      "eks/cluster_security_group_id" = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
      "ecr/php_repository_url"        = aws_ecr_repository.php.repository_url
      "apigw/api_id"                  = aws_apigatewayv2_api.this.id
      "apigw/execution_arn"           = aws_apigatewayv2_api.this.execution_arn
      "apigw/invoke_url"              = aws_apigatewayv2_stage.default.invoke_url
    },
    local.newrelic_enabled == 1 ? {
      "observability/firehose_arn"  = aws_kinesis_firehose_delivery_stream.newrelic_logs[0].arn
      "observability/logs_role_arn" = aws_iam_role.newrelic_logs_to_firehose[0].arn
    } : {}
  )
}

resource "aws_ssm_parameter" "contract" {
  for_each = local.ssm_parameters

  name  = "${var.ssm_prefix}/${each.key}"
  type  = "String"
  value = each.value
}
