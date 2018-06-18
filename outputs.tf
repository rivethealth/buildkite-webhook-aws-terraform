output "gateway_api_id" {
  value = "${aws_api_gateway_rest_api.buildkite.id}"
}

output "gateway_invoke_url" {
  value = "${aws_api_gateway_deployment.buildkite.invoke_url}"
}

output "gateway_stage_name" {
  value = "${aws_api_gateway_stage.buildkite.stage_name}"
}

output "sns_topic_arns" {
  value = "${aws_sns_topic.event.*.arn}"
}
