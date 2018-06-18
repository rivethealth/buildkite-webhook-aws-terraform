# Buildkite webhooks to AWS Terraform

* [Inputs](#inputs)
* [Outputs](#outputs)
* [Setup](#setup)
* [Examples](#usage)
  * [Basic](#basic)
  * [Custom domain](#custom-domain)

## Usage

The webhook token should be stored as a secure string in AWS Systems Manager Parameter Store. Use a comma separated list for multiple allowed tokens.

Multiple HTTP resources can be created. Each corresponds to a separate SNS topic.

SNS messages have an attribute "event" with the contents of X-Buildkite-Event. You may use this for subcription [filter policies](https://docs.aws.amazon.com/sns/latest/dg/message-filtering.html).

### Inputs

| Name | Type | Description | Default |
|------|:----:|-------------|:-------:|
| deploy_version | string | Arbitrary version to force deployment of API gateway | "1" |
| endpoints | list | Names of endpoints | ["all"] |
| name | string | Namespace for resources | "buildkite-events" |
| token_ssm_path | string | Parameter Store path to webhook token | - |

### Outputs

| Name | Type | Description |
|------|:----:|-------------|
| gateway_api_id | string | ID of API gateway |
| gateway_invoke_url | string | URL of deployed API |
| gateway_stage_name | string | Stage name of API gateway |
| sns_topic_arns | list | ARNs of SNS topics |

Requests can be made against "${gateway_invoke_url}/${endpoint}"

## Examples

### Basic

```hcl
module "buildkite-events" {
  token_ssm_path = "/buildkite/webhook-token"
  source         = "github.com/rivethealth/terraform-aws-buildkite-events"
}
```

### Custom domain

```hcl
data "aws_acm_certificate" "buildkite-events" {
  domain   = "buildkite-events.my-domain.com"
  statuses = ["ISSUED"]
}

module "buildkite-events" {
  token_ssm_path = "/buildkite/webhook-token"
  source         = "github.com/rivethealth/terraform-aws-buildkite-events"
}

resource "aws_api_gateway_base_path_mapping" "buildkite-events" {
  api_id      = "${module.buildkite-events.gateway_api_id}"
  stage_name  = "${module.buildkite-events.gateway_stage_name}"
  domain_name = "${aws_api_gateway_domain_name.buildkite-events.domain_name}"
}

resource "aws_api_gateway_domain_name" "buildkite-events" {
  certificate_arn = "${data.aws_acm_certificate.buildkite-events.arn}"
  domain_name     = "buildkite-events.my-domain.com"
}
```

Note that a custom domain name will not be ready for several minutes.
