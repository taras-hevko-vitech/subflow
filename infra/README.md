# infra — AWS CDK v2 (subF-5)

Реальний код інфри (навчальна ціль). Регіон **eu-central-1**. 4 стеки:

| Стек | Ресурси |
|------|---------|
| `Subflow-Network` | VPC, публічні сабнети, **без NAT Gateway** (guardrail) |
| `Subflow-Data` | RDS Postgres `t4g.micro` single-AZ + gp3; Secrets Manager (DB creds + token-encryption key); SSM param |
| `Subflow-App` | ECR; ECS cluster; Fargate (0.25 vCPU / 0.5 GB, 1 task, public IP); ALB; CloudWatch logs; health-check `/healthz` |
| `Subflow-Ops` | AWS Budget $55 (as code, алерти 50/85/100% + forecast → email); GitHub OIDC provider + deploy role |

## Оцінка вартості (steady-state, eu-central-1)

| Ресурс | Конфіг | ~$/міс |
|--------|--------|-------:|
| ALB | 1 ALB + низькі LCU | 18–22 |
| RDS | db.t4g.micro, single-AZ, 20GB gp3 | 15–17 |
| Fargate | 1×0.25 vCPU / 0.5 GB, 24/7 | 11–13 |
| Public IPv4 | ALB + task | 3–5 |
| CloudWatch | logs + alarms | 2–4 |
| Secrets Manager | 2 секрети | ~1 |
| ECR / SSM / Route53 | образи / params / zone | ~1 |
| Data transfer | низький | 1–2 |
| **NAT Gateway** | **уникнуто** | **0** |
| **Разом** | | **≈ $52–65** |

Budget alarm стоїть на **$55** — це трипвайр, не стеля; forecast-алерт попереджає про виповзання.

## Команди

```bash
cd infra
bun run synth                 # рендер CloudFormation (працює без акаунта)
# після створення AWS-акаунта:
export CDK_DEFAULT_ACCOUNT=<id>
bunx cdk bootstrap aws://<id>/eu-central-1
bun run deploy -- -c alertEmail=you@domain -c githubRepo=OWNER/subflow
```

## Що ще НЕ під'єднано (свідомо)

- **Домен / HTTPS / ACM / Route53** — `subflow.app` ще не зареєстрований. ALB поки HTTP.
  Після реєстрації hosted zone: ACM DNS-cert + HTTPS:443 listener + Route53 alias (TODO у `stacks/app.ts`).
- `cdk deploy` заблокований до створення окремого AWS-акаунта (зовнішній блокер).
- Перший деплой: спочатку запушити образ у ECR (`latest`), потім `cdk deploy` (сервіс тягне образ).
