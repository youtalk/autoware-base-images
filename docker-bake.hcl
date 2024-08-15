group "default" {
  targets = [
    "autoware-core-depend",
    "autoware-universe-depend",
    "exec-depend"]
}

// For docker/metadata-action
target "docker-metadata-action-autoware-core-depend" {}
target "docker-metadata-action-autoware-universe-depend" {}
target "docker-metadata-action-exec-depend" {}

target "autoware-core-depend" {
  inherits = ["docker-metadata-action-autoware-core-depend"]
  dockerfile = "Dockerfile"
  target = "autoware-core-depend"
}

target "autoware-universe-depend" {
  inherits = ["docker-metadata-action-autoware-universe-depend"]
  dockerfile = "Dockerfile"
  target = "autoware-universe-depend"
}

target "exec-depend" {
  inherits = ["docker-metadata-action-exec-depend"]
  dockerfile = "Dockerfile"
  target = "exec-depend"
}
