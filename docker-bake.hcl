variable "DOCKER_TAG" {
}
target "claude-code-python" {
  tags = [
    "futureys/claude-code-python-development:latest",
    "futureys/claude-code-python-development:${DOCKER_TAG}",
  ]
}