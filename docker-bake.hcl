variable "DOCKER_TAG" {
}
// Build args (including BASE_IMAGE) come from the same-named services in compose.yaml,
// which `docker buildx bake` loads together with this file by default.
target "claude-code-python" {
  tags = [
    "futureys/claude-code-python-development:latest",
    "futureys/claude-code-python-development:${DOCKER_TAG}",
  ]
}
target "claude-code-playwright-python" {
  tags = [
    "futureys/claude-code-playwright-python:latest",
    "futureys/claude-code-playwright-python:${DOCKER_TAG}",
  ]
}
// To prevent following error when testing `docker buildx bake` in development PC:
//   ERROR: Multi-platform build is not supported for the docker driver.
//   Switch to a different driver, or turn on the containerd image store, and try again.
//   Learn more at https://docs.docker.com/go/build-multi-platform/
target "_release" {
  platforms = ["linux/amd64", "linux/arm64"]
}
target "claude-code-python-release" {
  inherits = ["claude-code-python", "_release"]
}
target "claude-code-playwright-python-release" {
  inherits = ["claude-code-playwright-python", "_release"]
}
group "app-release" {
  targets = [
    "claude-code-python-release",
    "claude-code-playwright-python-release",
  ]
}
