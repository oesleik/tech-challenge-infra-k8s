# Borda pública: API Gateway (HTTP API) -> VPC Link -> NLB interno -> NodePort do EKS.
# Este repositório cria o API, o stage e a rota $default (aplicação PHP). Outros backends
# registram as próprias rotas no mesmo API lendo o api_id no SSM: a Lambda de autenticação
# cria POST /autenticacao no repositório tech-challenge-lambda.

resource "aws_security_group" "vpc_link" {
  name        = "${var.cluster_name}-apigw-vpc-link"
  description = "ENIs do VPC Link do API Gateway"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.cluster_name}-apigw-vpc-link"
  }
}

resource "aws_security_group" "nlb" {
  name        = "${var.cluster_name}-nlb"
  description = "NLB interno na frente do NodePort"
  vpc_id      = aws_vpc.this.id

  tags = {
    Name = "${var.cluster_name}-nlb"
  }
}

resource "aws_vpc_security_group_egress_rule" "vpc_link_to_nlb" {
  security_group_id            = aws_security_group.vpc_link.id
  description                  = "VPC Link para o NLB"
  referenced_security_group_id = aws_security_group.nlb.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

resource "aws_vpc_security_group_ingress_rule" "nlb_from_vpc_link" {
  security_group_id            = aws_security_group.nlb.id
  description                  = "Somente o VPC Link do API Gateway"
  referenced_security_group_id = aws_security_group.vpc_link.id
  from_port                    = 80
  ip_protocol                  = "tcp"
  to_port                      = 80
}

resource "aws_vpc_security_group_egress_rule" "nlb_to_nodeport" {
  security_group_id            = aws_security_group.nlb.id
  description                  = "NLB para o NodePort (trafego e health check)"
  referenced_security_group_id = aws_eks_cluster.this.vpc_config[0].cluster_security_group_id
  from_port                    = 30080
  ip_protocol                  = "tcp"
  to_port                      = 30080
}

resource "aws_lb" "api" {
  name               = "${var.cluster_name}-api"
  internal           = true
  load_balancer_type = "network"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.nlb.id]

  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "nodeport" {
  name        = "${var.cluster_name}-nodeport"
  port        = 30080
  protocol    = "TCP"
  target_type = "instance"
  vpc_id      = aws_vpc.this.id

  preserve_client_ip = false

  health_check {
    protocol = "HTTP"
    port     = "traffic-port"
    path     = "/nginx-health"
  }
}

resource "aws_lb_listener" "api" {
  load_balancer_arn = aws_lb.api.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.nodeport.arn
  }
}

resource "aws_autoscaling_attachment" "nodeport" {
  autoscaling_group_name = aws_eks_node_group.this.resources[0].autoscaling_groups[0].name
  lb_target_group_arn    = aws_lb_target_group.nodeport.arn
}

resource "aws_apigatewayv2_vpc_link" "this" {
  name               = "${var.cluster_name}-vpc-link"
  subnet_ids         = aws_subnet.public[*].id
  security_group_ids = [aws_security_group.vpc_link.id]
}

resource "aws_apigatewayv2_api" "this" {
  name          = "${var.cluster_name}-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_integration" "nlb" {
  api_id                 = aws_apigatewayv2_api.this.id
  integration_type       = "HTTP_PROXY"
  integration_method     = "ANY"
  integration_uri        = aws_lb_listener.api.arn
  connection_type        = "VPC_LINK"
  connection_id          = aws_apigatewayv2_vpc_link.this.id
  payload_format_version = "1.0"

  # Mesmo id do access log, para correlacionar com o request.id da aplicação no New Relic.
  request_parameters = {
    "overwrite:header.X-Request-Id" = "$context.requestId"
  }
}

resource "aws_apigatewayv2_route" "default" {
  api_id    = aws_apigatewayv2_api.this.id
  route_key = "$default"
  target    = "integrations/${aws_apigatewayv2_integration.nlb.id}"
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${var.cluster_name}-api"
  retention_in_days = 7
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.this.id
  name        = "$default"
  auto_deploy = true

  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId          = "$context.requestId"
      ip                 = "$context.identity.sourceIp"
      requestTime        = "$context.requestTime"
      httpMethod         = "$context.httpMethod"
      path               = "$context.path"
      status             = "$context.status"
      responseLength     = "$context.responseLength"
      responseLatency    = "$context.responseLatency"
      integrationLatency = "$context.integrationLatency"
      integrationStatus  = "$context.integrationStatus"
      integrationError   = "$context.integrationErrorMessage"
    })
  }
}
