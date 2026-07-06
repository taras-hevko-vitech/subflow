# infra — AWS CDK v2 (subF-5)

Infrastructure as real code (a deliberate learning goal). Region **eu-central-1**. 4 stacks:

| Stack | Resources |
|-------|-----------|
| `Subflow-Network` | VPC, public subnets, **no NAT Gateway** (cost guardrail) |
| `Subflow-Data` | RDS Postgres `t4g.micro` single-AZ + gp3; Secrets Manager (DB creds + token-encryption key); SSM param |
| `Subflow-App` | ECR; ECS cluster; Fargate (0.25 vCPU / 0.5 GB, 1 task, public IP); ALB; CloudWatch logs; `/health` health check |
| `Subflow-Ops` | AWS Budget $55 (as code, alerts at 50/85/100% + forecast → email); GitHub OIDC provider + deploy role |

## Cost estimate (steady-state, eu-central-1)

| Resource | Config | ~$/mo |
|----------|--------|------:|
| ALB | 1 ALB + low LCU | 18–22 |
| RDS | db.t4g.micro, single-AZ, 20GB gp3 | 15–17 |
| Fargate | 1×0.25 vCPU / 0.5 GB, 24/7 | 11–13 |
| Public IPv4 | ALB + task | 3–5 |
| CloudWatch | logs + alarms | 2–4 |
| Secrets Manager | 2 secrets | ~1 |
| ECR / SSM / Route53 | images / params / zone | ~1 |
| Data transfer | low | 1–2 |
| **NAT Gateway** | **avoided** | **0** |
| **Total** | | **≈ $52–65** |

The budget alarm is set to **$55** — a tripwire, not a ceiling; the forecast alert warns
about creeping costs.

## Commands

```bash
cd infra
bun run synth                 # render CloudFormation (works without an account)
# once the AWS account exists:
export CDK_DEFAULT_ACCOUNT=<id>
bunx cdk bootstrap aws://<id>/eu-central-1
bun run deploy -- -c alertEmail=you@domain -c githubRepo=OWNER/subflow
```

## Deliberately NOT wired up yet

- **Domain / HTTPS / ACM / Route53** — `subflow.app` is not registered yet. The ALB is
  plain HTTP for now. Once the hosted zone exists: ACM DNS cert + HTTPS:443 listener +
  Route53 alias (TODO in `stacks/app.ts`).
- `cdk deploy` is blocked until the dedicated AWS account is created (external blocker).
- First deploy: push the image to ECR (`latest`) first, then `cdk deploy` (the service
  pulls the image).

## Cost tradeoffs (documented per the guardrail rule)

- **No NAT Gateway** (~$32/mo saved): public subnets + public IPs on Fargate tasks; the
  RDS instance has no public IP and only allows ingress from within the VPC.
- **Single-AZ RDS**: acceptable for MVP; multi-AZ doubles the cost.
- **ALB kept** (~$20/mo): the single biggest fixed cost, but monobank webhooks need a
  stable public HTTPS endpoint, and managed TLS/health checks are worth it.
- **Fargate 0.25/0.5**: cheapest sane size; watch for OOM once detection + pg-boss run
  under load, bump to 0.5/1 if needed.
