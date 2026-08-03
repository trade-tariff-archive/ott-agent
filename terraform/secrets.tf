# ott-agent/terraform/secrets.tf
# Populate after first apply:
#   aws ssm put-parameter --name /ott-agent/playground/SECRET_KEY_BASE  --type SecureString --value <value>
#   aws ssm put-parameter --name /ott-agent/playground/MCP_CLIENT_ID     --type SecureString --value <value>
#   aws ssm put-parameter --name /ott-agent/playground/MCP_CLIENT_SECRET --type SecureString --value <value>

data "aws_ssm_parameter" "secret_key_base" {
  name = "/ott-agent/${var.environment}/SECRET_KEY_BASE"
}

data "aws_ssm_parameter" "mcp_client_id" {
  name = "/ott-agent/${var.environment}/MCP_CLIENT_ID"
}

data "aws_ssm_parameter" "mcp_client_secret" {
  name = "/ott-agent/${var.environment}/MCP_CLIENT_SECRET"
}
