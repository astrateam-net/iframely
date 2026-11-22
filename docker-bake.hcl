target "docker-metadata-action" {}

variable "SOURCE" {
  default = "https://github.com/astrateam-net/iframely"
}

group "default" {
  targets = ["image-local"]
}

// Upstream's own Dockerfile on the assembled tree: `mise run up` first, so the series and overlay
// are in lib/iframely before the context is sent. CI sets the other OCI labels.
target "image" {
  inherits = ["docker-metadata-action"]
  context  = "lib/iframely"
  labels = {
    "org.opencontainers.image.source" = "${SOURCE}"
  }
}

target "image-local" {
  inherits = ["image"]
  output   = ["type=docker"]
}

target "image-all" {
  inherits  = ["image"]
  platforms = ["linux/amd64"]
}
