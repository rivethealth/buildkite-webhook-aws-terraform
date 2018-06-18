data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

data "archive_file" "lambda" {
  source_dir  = "${path.module}/authorizer"
  output_path = "${path.module}/authorizer.zip"
  type        = "zip"
}

resource "aws_api_gateway_authorizer" "api" {
  authorizer_credentials           = "${aws_iam_role.api.arn}"
  authorizer_result_ttl_in_seconds = 180
  authorizer_uri                   = "${aws_lambda_function.authorizer.invoke_arn}"
  identity_source                  = "method.request.header.X-Buildkite-Token"
  name                             = "api"
  rest_api_id                      = "${aws_api_gateway_rest_api.buildkite.id}"
  type                             = "TOKEN"
}

resource "aws_api_gateway_deployment" "buildkite" {
  depends_on        = ["aws_api_gateway_integration_response.event"]
  stage_description = "${var.deploy_version}"
  stage_name        = ""
  rest_api_id       = "${aws_api_gateway_rest_api.buildkite.id}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_integration" "event" {
  count                   = "${length(var.endpoints)}"
  credentials             = "${aws_iam_role.api.arn}"
  http_method             = "${aws_api_gateway_method.event.*.http_method[count.index]}"
  integration_http_method = "POST"
  resource_id             = "${aws_api_gateway_method.event.*.resource_id[count.index]}"
  rest_api_id             = "${aws_api_gateway_rest_api.buildkite.id}"
  type                    = "AWS"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sns:path//"

  request_parameters {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }

  request_templates {
    "application/json" = <<EOF
Action=Publish##
&Message=$util.urlEncode($input.body)##
&MessageAttributes.entry.1.Name=event##
&MessageAttributes.entry.1.Value.DataType=String##
&MessageAttributes.entry.1.Value.StringValue=$util.urlEncode($input.params('X-Buildkite-Event'))##
&TopicArn=${urlencode(aws_sns_topic.event.*.arn[count.index])}##
EOF
  }
}

resource "aws_api_gateway_integration_response" "event" {
  count       = "${length(var.endpoints)}"
  rest_api_id = "${aws_api_gateway_rest_api.buildkite.id}"
  resource_id = "${aws_api_gateway_method.event.*.resource_id[count.index]}"
  http_method = "POST"
  status_code = "${aws_api_gateway_method_response.event-200.*.status_code[count.index]}"
  depends_on  = ["aws_api_gateway_integration.event"]
}

resource "aws_api_gateway_method" "event" {
  authorization        = "CUSTOM"
  authorizer_id        = "${aws_api_gateway_authorizer.api.id}"
  count                = "${length(var.endpoints)}"
  http_method          = "POST"
  request_validator_id = "${aws_api_gateway_request_validator.buildkite.id}"
  resource_id          = "${aws_api_gateway_resource.event.*.id[count.index]}"
  rest_api_id          = "${aws_api_gateway_rest_api.buildkite.id}"

  request_parameters {
    method.request.header.X-Buildkite-Event = true
  }
}

resource "aws_api_gateway_method_response" "event-200" {
  count       = "${length(var.endpoints)}"
  http_method = "${aws_api_gateway_method.event.*.http_method[count.index]}"
  resource_id = "${aws_api_gateway_method.event.*.resource_id[count.index]}"
  rest_api_id = "${aws_api_gateway_rest_api.buildkite.id}"
  status_code = 200
}

resource "aws_api_gateway_method_settings" "buildkite" {
  method_path = "*/*"
  rest_api_id = "${aws_api_gateway_rest_api.buildkite.id}"
  stage_name  = "${aws_api_gateway_stage.buildkite.stage_name}"

  settings {
    metrics_enabled = true
    logging_level   = "INFO"
  }
}

resource "aws_api_gateway_request_validator" "buildkite" {
  name                        = "validate"
  rest_api_id                 = "${aws_api_gateway_rest_api.buildkite.id}"
  validate_request_parameters = true
}

resource "aws_api_gateway_resource" "event" {
  count       = "${length(var.endpoints)}"
  parent_id   = "${aws_api_gateway_rest_api.buildkite.root_resource_id}"
  path_part   = "${var.endpoints[count.index]}"
  rest_api_id = "${aws_api_gateway_rest_api.buildkite.id}"
}

resource "aws_api_gateway_rest_api" "buildkite" {
  description = "Buildkite webhook consumer"
  name        = "${var.name}"
}

resource "aws_api_gateway_stage" "buildkite" {
  deployment_id = "${aws_api_gateway_deployment.buildkite.id}"
  rest_api_id   = "${aws_api_gateway_rest_api.buildkite.id}"
  stage_name    = "latest"

  access_log_settings {
    destination_arn = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/buildkite/webhook/access"
    format          = "$context.identity.sourceIp $context.identity.caller $context.identity.user [$context.requestTime] $context.httpMethod $context.resourcePath $context.protocol $context.status $context.responseLength $context.requestId"
  }
}

resource "aws_iam_role" "api" {
  name = "${var.name}-api"
  path = "/buildkite/"

  assume_role_policy = <<EOF
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Sid": ""
    }
  ],
  "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role" "authorizer" {
  name = "${var.name}-authorizer"
  path = "/buildkite/"

  assume_role_policy = <<EOF
{
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      }
    }
  ],
  "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy" "api-authorizer" {
  name = "authorizer"
  role = "${aws_iam_role.api.id}"

  policy = <<EOF
{
  "Statement": [
    {
      "Action": "lambda:InvokeFunction",
      "Effect": "Allow",
      "Resource": "${aws_lambda_function.authorizer.arn}"
    }
  ],
  "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy" "api-sns" {
  name = "sns"
  role = "${aws_iam_role.api.id}"

  policy = <<EOF
{
  "Statement": [
    {
      "Action": "sns:Publish",
      "Effect": "Allow",
      "Resource": ${jsonencode(aws_sns_topic.event.*.arn)}
    }
  ],
  "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy" "authorizer-ssm" {
  name = "ssm"
  role = "${aws_iam_role.authorizer.id}"

  policy = <<EOF
{
  "Statement": [
    {
      "Action": "ssm:GetParameter",
      "Effect": "Allow",
      "Resource": "arn:aws:ssm:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:parameter${var.token_ssm_path}"
    }
  ],
  "Version": "2012-10-17"
}
EOF
}

resource "aws_iam_role_policy_attachment" "authorizer" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = "${aws_iam_role.api.id}"
}

resource "aws_lambda_function" "authorizer" {
  description      = "Authorize buildkite events"
  filename         = "${path.module}/authorizer.zip"
  function_name    = "buildkite-webhook-authorizer"
  handler          = "index.handler"
  publish          = true
  role             = "${aws_iam_role.authorizer.arn}"
  runtime          = "nodejs8.10"
  source_code_hash = "${data.archive_file.lambda.output_base64sha256}"
  timeout          = 30

  environment {
    variables {
      TOKEN_PATH = "${var.token_ssm_path}"
    }
  }
}

resource "aws_sns_topic" "event" {
  count = "${length(var.endpoints)}"
  name  = "${var.name}-${var.endpoints[count.index]}"
}
