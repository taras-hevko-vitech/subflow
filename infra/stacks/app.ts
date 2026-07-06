import { CfnOutput, Duration, RemovalPolicy, Stack, type StackProps } from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as ecr from "aws-cdk-lib/aws-ecr";
import * as ecs from "aws-cdk-lib/aws-ecs";
import * as ecsPatterns from "aws-cdk-lib/aws-ecs-patterns";
import * as logs from "aws-cdk-lib/aws-logs";
import type * as rds from "aws-cdk-lib/aws-rds";
import type * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import type { Construct } from "constructs";

interface AppStackProps extends StackProps {
  vpc: ec2.IVpc;
  db: rds.DatabaseInstance;
  tokenKeySecret: secretsmanager.ISecret;
}

export class AppStack extends Stack {
  constructor(scope: Construct, id: string, props: AppStackProps) {
    super(scope, id, props);

    const repo = new ecr.Repository(this, "ApiRepo", {
      repositoryName: "subflow-api",
      removalPolicy: RemovalPolicy.DESTROY,
      emptyOnDelete: true,
      lifecycleRules: [{ maxImageCount: 10 }],
    });

    const cluster = new ecs.Cluster(this, "Cluster", { vpc: props.vpc });

    const logGroup = new logs.LogGroup(this, "ApiLogs", {
      retention: logs.RetentionDays.TWO_WEEKS,
      removalPolicy: RemovalPolicy.DESTROY,
    });

    // dbSecret is the RDS-generated JSON secret (host/port/username/password/dbname).
    const dbSecret = props.db.secret!;

    const service = new ecsPatterns.ApplicationLoadBalancedFargateService(this, "Api", {
      cluster,
      cpu: 256,
      memoryLimitMiB: 512,
      desiredCount: 1,
      publicLoadBalancer: true,
      // Public subnets + public IP (no NAT). Cost guardrail — task pulls from ECR directly.
      assignPublicIp: true,
      taskSubnets: { subnetType: ec2.SubnetType.PUBLIC },
      healthCheckGracePeriod: Duration.seconds(60),
      taskImageOptions: {
        image: ecs.ContainerImage.fromEcrRepository(repo, "latest"),
        containerPort: 3000,
        environment: { NODE_ENV: "production", PORT: "3000" },
        // subF-7 assembles DATABASE_URL from these discrete fields at boot.
        secrets: {
          DB_HOST: ecs.Secret.fromSecretsManager(dbSecret, "host"),
          DB_PORT: ecs.Secret.fromSecretsManager(dbSecret, "port"),
          DB_USER: ecs.Secret.fromSecretsManager(dbSecret, "username"),
          DB_PASSWORD: ecs.Secret.fromSecretsManager(dbSecret, "password"),
          DB_NAME: ecs.Secret.fromSecretsManager(dbSecret, "dbname"),
          TOKEN_ENCRYPTION_KEY: ecs.Secret.fromSecretsManager(props.tokenKeySecret),
        },
        logDriver: ecs.LogDrivers.awsLogs({ streamPrefix: "api", logGroup }),
      },
    });

    service.targetGroup.configureHealthCheck({
      path: "/healthz",
      healthyHttpCodes: "200",
    });

    new CfnOutput(this, "AlbUrl", {
      value: `http://${service.loadBalancer.loadBalancerDnsName}`,
    });
    new CfnOutput(this, "EcrRepoUri", { value: repo.repositoryUri });

    // TODO(subF-5, once subflow.app is registered in Route53): add an ACM DNS-validated
    // cert, switch the ALB listener to HTTPS:443, and add a Route53 alias record. Gated on
    // the hosted zone so `cdk synth` needs no account or context lookups today.
  }
}
