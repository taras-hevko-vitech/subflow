import { Duration, RemovalPolicy, Stack, type StackProps } from "aws-cdk-lib";
import * as ec2 from "aws-cdk-lib/aws-ec2";
import * as rds from "aws-cdk-lib/aws-rds";
import * as secretsmanager from "aws-cdk-lib/aws-secretsmanager";
import * as ssm from "aws-cdk-lib/aws-ssm";
import type { Construct } from "constructs";

interface DataStackProps extends StackProps {
  vpc: ec2.IVpc;
}

export class DataStack extends Stack {
  readonly db: rds.DatabaseInstance;
  readonly tokenKeySecret: secretsmanager.Secret;

  constructor(scope: Construct, id: string, props: DataStackProps) {
    super(scope, id, props);

    // Postgres SG: ingress from within the VPC only. The DB has no public IP, and the VPC
    // holds just the Fargate task, so a VPC-CIDR peer (rather than a cross-stack service SG)
    // is both safe enough for MVP and avoids an App<->Data dependency cycle.
    const dbSg = new ec2.SecurityGroup(this, "DbSg", {
      vpc: props.vpc,
      description: "Postgres ingress",
      allowAllOutbound: true,
    });
    dbSg.addIngressRule(ec2.Peer.ipv4(props.vpc.vpcCidrBlock), ec2.Port.tcp(5432), "VPC to Postgres");

    // db.t4g.micro, single-AZ, small gp3 — cheapest sane Postgres (~$15/mo). Postgres also
    // hosts the pg-boss queue schema (no Redis).
    this.db = new rds.DatabaseInstance(this, "Db", {
      engine: rds.DatabaseInstanceEngine.postgres({
        version: rds.PostgresEngineVersion.VER_16,
      }),
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.BURSTABLE4_GRAVITON, ec2.InstanceSize.MICRO),
      vpc: props.vpc,
      vpcSubnets: { subnetType: ec2.SubnetType.PUBLIC },
      securityGroups: [dbSg],
      // No public IP → not internet-reachable even though the subnet is public. Only the
      // shared client SG may reach 5432.
      publiclyAccessible: false,
      multiAz: false,
      allocatedStorage: 20,
      storageType: rds.StorageType.GP3,
      databaseName: "subflow",
      credentials: rds.Credentials.fromGeneratedSecret("subflow"),
      backupRetention: Duration.days(7),
      deletionProtection: false,
      removalPolicy: RemovalPolicy.SNAPSHOT,
    });

    // AES-256-GCM key for bank-token encryption (subF-7). 32 chars = 32 bytes. Lives ONLY
    // in Secrets Manager — never in the DB or repo.
    this.tokenKeySecret = new secretsmanager.Secret(this, "TokenEncryptionKey", {
      secretName: "subflow/token-encryption-key",
      generateSecretString: {
        passwordLength: 32,
        excludePunctuation: true,
      },
    });

    new ssm.StringParameter(this, "RegionParam", {
      parameterName: "/subflow/region",
      stringValue: this.region,
    });
  }
}
