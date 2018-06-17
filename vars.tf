variable "deploy_version" {
  default = "1"
}

variable "endpoints" {
  default = ["all", "foo"]
  type    = "list"
}

variable "name" {
  default = "buildkite"
}

variable "token_ssm_path" {}
