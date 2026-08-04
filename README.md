# OTT Agent

A standalone AI agent for the [GOV.UK Online Trade Tariff](https://www.trade-tariff.service.gov.uk/) — spike for HMRC-2595.

The app wires AWS Bedrock (Claude via the Converse API) to the Trade Tariff MCP server, exposing a Turbo Streams chat UI and a standing-intent watchlist that fires alerts when commodity data changes.

---

## Architecture

```
Browser ──Turbo Streams──▶ Rails 8.1 (Puma, port 3010)
                                │
                    ┌───────────┴───────────┐
                    │                       │
             AgentService          StandingIntentCheckJob
             (Bedrock Converse)    (Sidekiq cron, every 6h)
                    │                       │
              McpClient ◀──────────── McpClient
        (Trade Tariff MCP server)
```

- **No login** — visitor identity is a UUID stored in the session cookie.
- **Bedrock auth** — IAM task role; no API key stored.
- **MCP auth** — `McpClient` exchanges `MCP_CLIENT_ID`/`MCP_CLIENT_SECRET` against the Hub (Cognito client-credentials grant) and caches the JWT until 60 s before expiry.
- **Tool-use loop** — up to 10 iterations per response, with an exhaustion guard that surfaces a truncation notice rather than an empty reply.
- **Standing intents** — diff-gated via the `commodity_history_diff` MCP tool (SHA-256 comparison); the LLM is only called when the data actually changes.

---

## Local development

### Prerequisites

- Ruby 4.0.5 (via asdf or rbenv)
- PostgreSQL 15+
- Redis 7+
- MCP client credentials (from Devhub)
- AWS credentials with Bedrock access (`eu-west-2`, `eu.anthropic.claude-*` inference profiles)

### Setup

```bash
cp .env.development .env.development.local
# Fill in MCP_CLIENT_ID, MCP_CLIENT_SECRET, AWS_PROFILE / AWS_ACCESS_KEY_ID etc.

bundle install
bundle exec rails db:create db:migrate
bundle exec rails server -p 3010
```

Open <http://localhost:3010>.

### Running tests

```bash
bundle exec rspec
```

### With Docker Compose

```bash
export MCP_URL=https://mcp.dev.trade-tariff.service.gov.uk
export MCP_CLIENT_ID=<id>
export MCP_CLIENT_SECRET=<secret>
export AWS_REGION=eu-west-2

make build
make run        # starts postgres, redis, app, sidekiq
```

Open <http://localhost:3010>.

---

## Benchmark

Runs 20 representative queries across 7 categories (commodity lookup, classification, duty calculation, rules of origin, quotas, history, navigation) and writes a summary table to stdout plus a CSV to `tmp/benchmark_results.csv`.

```bash
MCP_URL=https://mcp.dev.trade-tariff.service.gov.uk \
  MCP_CLIENT_ID=<id> \
  MCP_CLIENT_SECRET=<secret> \
  AWS_REGION=eu-west-2 \
  AWS_PROFILE=playground \
  bundle exec ruby bin/benchmark
```

---

## AWS playground deployment

### One-time bootstrap

**1. Create the Terraform state bucket:**

```bash
aws s3api create-bucket \
  --bucket ott-agent-terraform-state \
  --region eu-west-2 \
  --create-bucket-configuration LocationConstraint=eu-west-2

aws s3api put-bucket-versioning \
  --bucket ott-agent-terraform-state \
  --versioning-configuration Status=Enabled
```

**2. Populate SSM secrets:**

```bash
aws ssm put-parameter --name /ott-agent/playground/SECRET_KEY_BASE \
  --type SecureString --value "$(bundle exec rails secret)" --region eu-west-2

aws ssm put-parameter --name /ott-agent/playground/MCP_CLIENT_ID \
  --type SecureString --value "<id-from-devhub>" --region eu-west-2

aws ssm put-parameter --name /ott-agent/playground/MCP_CLIENT_SECRET \
  --type SecureString --value "<secret-from-devhub>" --region eu-west-2
```

**3. Build and push the Docker image:**

```bash
AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
ECR_URL="${AWS_ACCOUNT}.dkr.ecr.eu-west-2.amazonaws.com/ott-agent"

aws ecr get-login-password --region eu-west-2 \
  | docker login --username AWS --password-stdin "$ECR_URL"

docker build --platform linux/amd64 -t "${ECR_URL}:latest" .
docker push "${ECR_URL}:latest"
```

**4. Apply Terraform:**

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
# → outputs: alb_dns_name, ecr_repository_url
```

**5. Run migrations (one-off ECS task):**

```bash
CLUSTER="ott-agent-playground"
TASK_DEF=$(aws ecs describe-task-definition --task-definition ott-agent-playground \
  --query taskDefinition.taskDefinitionArn --output text)
SUBNET=$(aws ec2 describe-subnets --filters "Name=defaultForAz,Values=true" \
  --query "Subnets[0].SubnetId" --output text)
SG=$(aws ec2 describe-security-groups \
  --filters "Name=group-name,Values=ott-agent-task-playground" \
  --query "SecurityGroups[0].GroupId" --output text)

aws ecs run-task \
  --cluster "$CLUSTER" \
  --task-definition "$TASK_DEF" \
  --launch-type FARGATE \
  --network-configuration "awsvpcConfiguration={subnets=[${SUBNET}],securityGroups=[${SG}],assignPublicIp=ENABLED}" \
  --overrides '{"containerOverrides":[{"name":"ott-agent","command":["bundle","exec","rails","db:migrate"]}]}'
```

Visit `http://<alb_dns_name>/healthcheckz` → `200 OK`.

### Subsequent deploys

```bash
docker build --platform linux/amd64 -t "${ECR_URL}:latest" . && docker push "${ECR_URL}:latest"

aws ecs update-service --cluster ott-agent-playground \
  --service ott-agent-playground --force-new-deployment
```

---

## Environment variables

| Variable | Required | Description |
|---|---|---|
| `MCP_URL` | Yes | Trade Tariff MCP server base URL |
| `MCP_HUB_TOKEN_URL` | Yes | Cognito token endpoint (default: GOV.UK Hub) |
| `MCP_CLIENT_ID` | Yes | Devhub OAuth client ID |
| `MCP_CLIENT_SECRET` | Yes | Devhub OAuth client secret |
| `AWS_REGION` | Yes | AWS region (default: `eu-west-2`) |
| `SECRET_KEY_BASE` | Yes | Rails secret key base |
| `DATABASE_URL` or `DB_*` | Yes | PostgreSQL connection |
| `REDIS_URL` | Yes | Redis connection (default: `redis://localhost:6379/0`) |
| `AWS_PROFILE` | Local only | AWS credentials profile (IAM role used in ECS) |
