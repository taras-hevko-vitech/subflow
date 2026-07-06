import { App } from "aws-cdk-lib";
import { AppStack } from "../stacks/app";
import { DataStack } from "../stacks/data";
import { NetworkStack } from "../stacks/network";
import { OpsStack } from "../stacks/ops";

const app = new App();

// Account is resolved at deploy time (unset until the AWS account exists + `cdk bootstrap`).
// `cdk synth` works without it. Region is fixed to eu-central-1 (Frankfurt).
const env = {
  account: process.env.CDK_DEFAULT_ACCOUNT,
  region: process.env.CDK_DEFAULT_REGION ?? "eu-central-1",
};

const alertEmail = app.node.tryGetContext("alertEmail") ?? "alerts@example.com";
const githubRepo = app.node.tryGetContext("githubRepo") ?? "OWNER/subflow";

const network = new NetworkStack(app, "Subflow-Network", { env });

const data = new DataStack(app, "Subflow-Data", { env, vpc: network.vpc });

new AppStack(app, "Subflow-App", {
  env,
  vpc: network.vpc,
  db: data.db,
  tokenKeySecret: data.tokenKeySecret,
});

new OpsStack(app, "Subflow-Ops", { env, alertEmail, githubRepo });
