output "gateway_api_id" {
  value = "${aws_api_gateway_rest_api.buildkite.id}"
}

output "gateway_stage_name" {
  value = "${aws_api_gateway_deployment.buildkite.stage_name}"
}
