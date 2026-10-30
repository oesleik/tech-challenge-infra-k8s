output "cluster_name" {
  value = aws_eks_cluster.this.name
}

output "cluster_endpoint" {
  value = aws_eks_cluster.this.endpoint
}

output "vpc_id" {
  value = aws_vpc.this.id
}

output "kubeconfig_command" {
  value = "aws eks update-kubeconfig --name ${var.cluster_name} --region ${var.aws_region}"
}

output "api_gateway_url" {
  value       = aws_apigatewayv2_stage.default.invoke_url
  description = "Única entrada pública da API (o NodePort só aceita o NLB interno)."
}

output "ecr_repository_url" {
  value       = aws_ecr_repository.php.repository_url
  description = "URI da imagem PHP no ECR."
}

output "ssm_parameters" {
  value       = sort([for p in aws_ssm_parameter.contract : p.name])
  description = "Parâmetros publicados como contrato para os outros repositórios."
}

output "newrelic_integration_role_arn" {
  value       = one(aws_iam_role.newrelic_integration[*].arn)
  description = "Role do API polling. Usada uma vez no cloudLinkAccount do NerdGraph."
}

output "newrelic_dashboard_url" {
  value       = one(newrelic_one_dashboard.tech_challenge[*].permalink)
  description = "Dashboard tech-challenge no New Relic."
}
