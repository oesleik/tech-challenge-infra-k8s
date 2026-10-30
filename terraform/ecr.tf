# Repositório da imagem PHP. O build e o push são feitos pelo deploy da aplicação
# (tech-chalange), que lê a URL no SSM.
resource "aws_ecr_repository" "php" {
  name                 = "tech-challenge-php"
  image_tag_mutability = "MUTABLE"
  force_delete         = true

  image_scanning_configuration {
    scan_on_push = true
  }
}
