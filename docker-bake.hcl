group "default" {
  targets = [
    "autoware-core-base",
    "autoware-universe-base",
    "runtime-base"]
}

// For docker/metadata-action
target "docker-metadata-action-autoware-core-base" {}
target "docker-metadata-action-autoware-universe-base" {}
target "docker-metadata-action-runtime-base" {}

target "autoware-core-base" {
  inherits = ["docker-metadata-action-autoware-core-base"]
  dockerfile = "Dockerfile"
  target = "autoware-core-base"
}

target "autoware-universe-base" {
  inherits = ["docker-metadata-action-autoware-universe-base"]
  dockerfile = "Dockerfile"
  target = "autoware-universe-base"
}

target "runtime-base" {
  inherits = ["docker-metadata-action-runtime-base"]
  dockerfile = "Dockerfile"
  target = "runtime-base"
}
