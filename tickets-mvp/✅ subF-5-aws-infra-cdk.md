# subF-5 · Інфраструктура AWS (CDK v2)
**Фаза:** 1 · **Розмір:** M · **Блокери:** subF-4 (є що деплоїти) + окремий AWS-акаунт (зовнішній)
**Регіон:** eu-central-1 · **Навчальна ціль:** інфра — реальний код у `infra/`, не консоль

## Стеки CDK (`infra/stacks/`)
- [ ] **NetworkStack** — VPC, ПУБЛІЧНІ сабнети (БЕЗ NAT Gateway — cost guardrail), Security Groups
- [ ] **DataStack** — RDS PostgreSQL `db.t4g.micro` single-AZ, 20GB gp3; Secrets Manager: DB creds + token-encryption key (AES-256-GCM); SSM Parameter Store: plain config
- [ ] **AppStack** — ECR; ECS cluster; Fargate service (1 task, 0.25 vCPU / 0.5 GB — старт дешево, моніторити OOM); ALB + ACM cert; Route53 A-record на subflow.app; CloudWatch log group + alarms
- [ ] **OpsStack** — AWS Budget alarm (as code) $55 з алертами 50/85/100% + forecast → SNS; GitHub OIDC provider + least-privilege deploy role для CI (subF-4)

## Домен / TLS
- [ ] Зареєструвати subflow.app (Route53 у цьому ж акаунті); .app — HTTPS-only → ACM-cert обов'язковий
- [ ] Записи для SES DKIM (subF-6) і AASA/assetlinks (subF-13)

## Cost guardrails (задокументувати кожен трейдоф у `infra/README.md`)
- [ ] БЕЗ NAT Gateway (публічні сабнети + public IP на таску)
- [ ] single-AZ де прийнятно; Fargate 0.25/0.5 на старті
- [ ] Очікуваний steady-state ~$52–65/міс (домінує ALB ~$20 + RDS ~$15 + Fargate ~$12)

## Acceptance Criteria
`cdk synth` проходить для всіх стеків; після створення акаунта + `cdk bootstrap` → `cdk deploy` піднімає ALB, `/health` зелений через ALB на HTTPS, secrets створені, Budget alarm видно в консолі, у VPC НЕМАЄ NAT Gateway. CI ассьюмить OIDC-роль і деплоїть без довгоживучих ключів.
