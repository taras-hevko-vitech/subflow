import { Aws, Stack, type StackProps } from "aws-cdk-lib";
import * as budgets from "aws-cdk-lib/aws-budgets";
import * as iam from "aws-cdk-lib/aws-iam";
import type { Construct } from "constructs";

interface OpsStackProps extends StackProps {
  alertEmail: string;
  /** "owner/repo" allowed to assume the deploy role. */
  githubRepo: string;
}

export class OpsStack extends Stack {
  constructor(scope: Construct, id: string, props: OpsStackProps) {
    super(scope, id, props);

    // --- Budget guardrail (as code): $55/mo, warn early + on forecast ---
    new budgets.CfnBudget(this, "MonthlyBudget", {
      budget: {
        budgetName: "subflow-monthly",
        budgetType: "COST",
        timeUnit: "MONTHLY",
        budgetLimit: { amount: 55, unit: "USD" },
      },
      notificationsWithSubscribers: [
        threshold("ACTUAL", 50, props.alertEmail),
        threshold("ACTUAL", 85, props.alertEmail),
        threshold("ACTUAL", 100, props.alertEmail),
        threshold("FORECASTED", 100, props.alertEmail),
      ],
    });

    // --- GitHub Actions OIDC deploy role (no long-lived AWS keys in CI) ---
    const oidc = new iam.OpenIdConnectProvider(this, "GithubOidc", {
      url: "https://token.actions.githubusercontent.com",
      clientIds: ["sts.amazonaws.com"],
    });

    const deployRole = new iam.Role(this, "GithubDeployRole", {
      roleName: "subflow-github-deploy",
      assumedBy: new iam.WebIdentityPrincipal(oidc.openIdConnectProviderArn, {
        StringEquals: {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        },
        StringLike: {
          "token.actions.githubusercontent.com:sub": `repo:${props.githubRepo}:*`,
        },
      }),
      description: "Assumed by GitHub Actions to run cdk deploy / push to ECR",
    });

    // Least-privilege: CI only assumes the CDK bootstrap roles, which hold the real perms.
    deployRole.addToPolicy(
      new iam.PolicyStatement({
        actions: ["sts:AssumeRole"],
        resources: [`arn:aws:iam::${Aws.ACCOUNT_ID}:role/cdk-*`],
      }),
    );
  }
}

function threshold(
  type: "ACTUAL" | "FORECASTED",
  pct: number,
  email: string,
): budgets.CfnBudget.NotificationWithSubscribersProperty {
  return {
    notification: {
      notificationType: type,
      comparisonOperator: "GREATER_THAN",
      threshold: pct,
      thresholdType: "PERCENTAGE",
    },
    subscribers: [{ subscriptionType: "EMAIL", address: email }],
  };
}
