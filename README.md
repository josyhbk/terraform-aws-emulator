# terraform-aws-emulator

How I lay out Terraform for a multi-account AWS setup, tested end to end
against a local AWS emulator. No AWS account and no credentials: CI plans
every pull request and deploys dev, stage and prod on every merge, with
three emulated accounts plus a DNS account.

What it builds in each environment:

![Architecture of one environment](docs/architecture.drawio.png)

Drawn with [drawio-aws-diagram](https://github.com/josyhbk/devops-ai-skills/tree/main/drawio-aws-diagram),
a Claude Code skill from my [devops-ai-skills](https://github.com/josyhbk/devops-ai-skills)
repo. The PNG has the diagram embedded, so it opens for editing in draw.io.

## Layout

```
terraform/            the root module, one for every environment
  backend.tf          partial S3 backend, the rest comes from backend.<env>.hcl
  provider.tf         default provider plus the us-east-1 alias for ACM
  versions.tf  locals.tf  variables.tf  main.tf  outputs.tf
  envs/<env>.tfvars   what differs between environments
modules/
  vpc/                      three-tier VPC on terraform-aws-modules/vpc
  cloudfront_distribution/  private S3 bucket behind CloudFront
  dns_acm/                  certificate only, DNS lives in another account
scripts/
  bootstrap.sh        state bucket per account, writes backend.<env>.hcl
  terraform.sh        the only way Terraform runs, locally and in CI
  emulator.sh         local AWS in Docker
  smoke.sh            checks a deployed environment actually works
emulator/aws-config   emulator profiles, fake keys
app/                  the API function and the static site
```

Community modules in use: vpc, s3-bucket, dynamodb-table, lambda and
apigateway-v2 from [terraform-aws-modules](https://github.com/terraform-aws-modules).
The custom modules wrap or sit next to them where the opinion is mine:
subnet layout, gateway endpoints, origin access control, and keeping DNS out
of the certificate module.

## How environments work

- **One account per environment.** `scripts/terraform.sh <env> ...` sets
  `AWS_PROFILE=<prefix>-<env>` (prefix `showcase` unless `PROFILE_PREFIX` says
  otherwise). Profiles live in your AWS config, not in this repo.
- **One state bucket per account,** created by `scripts/bootstrap.sh <env>` and
  named `<project>-terraform-backend-<env>-<account id>`. The script writes
  `terraform/backend.<env>.hcl`, which is git-ignored because it holds the
  account id.
- **Workspaces** separate each environment's state, and `locals.tf` reads the
  environment from `terraform.workspace`.
- **Wrong-account guard.** Before anything runs, the wrapper compares the
  profile's account with the account in the state bucket name and stops on a
  mismatch, so a stale `AWS_PROFILE` can't plan dev against prod's state.

## Run it locally

Needs Docker, Terraform 1.11 or newer, AWS CLI v2 and jq.

```bash
export AWS_CONFIG_FILE=$PWD/emulator/aws-config

scripts/emulator.sh up dev                 # Floci in Docker, accounts per profile
scripts/bootstrap.sh dev                   # state bucket + backend.dev.hcl
scripts/terraform.sh dev apply-dns         # first apply of an environment
EMULATOR=1 scripts/smoke.sh dev            # site, API, DNS
scripts/terraform.sh dev plan              # day to day
scripts/emulator.sh down
```

The smoke test prints the site's local URL,
`http://<id>.cloudfront.localhost.floci.io:4566`, which opens in a browser.
`localhost.floci.io` resolves to 127.0.0.1.

## Custom domains: apply-dns

stage and prod serve the site on their own domain. The hosted zone is in a
separate DNS account and CloudFront refuses a certificate that is not issued
yet, so the first apply of an environment goes through `apply-dns`:

1. apply only `module.dns_acm`, which requests the certificate
2. publish its validation records in the DNS account
3. `aws acm wait certificate-validated`
4. full apply
5. alias the domain to the distribution

Each step is idempotent. Running a plain `apply` first stops at a
precondition that names the command to use, before CloudFront is touched.
The emulator holds certificates in `PENDING_VALIDATION` for 15 seconds, so
the wait is real.

## CI

`.github/workflows/terraform.yml`, all of it against the emulator:

| When | What runs |
|---|---|
| Every PR and merge | `fmt`, `validate`, tflint with the AWS ruleset, Checkov, `terraform test` for each module with a mocked provider |
| Pull request | a plan per environment, summarised on the run |
| Merge to main | dev, then stage, then prod: bootstrap, `apply-dns`, smoke test, then a second plan that must report no changes |

prod runs in a GitHub environment that waits for approval. Checkov skips are
listed with their reasons in `.checkov.yaml`.

## On real AWS

Nothing in `terraform/` or `modules/` knows about the emulator. To point it
at real accounts:

1. Create profiles `<prefix>-dev`, `<prefix>-stage`, `<prefix>-prod` and
   `<prefix>-dns` in `~/.aws/config` (IAM Identity Center is the usual way).
2. Run `scripts/bootstrap.sh <env>` once per account.
3. Use the same `scripts/terraform.sh` commands.

In CI, swap the emulator step for `aws-actions/configure-aws-credentials`
with an OIDC role per environment.

Rough monthly cost in us-east-1 at low traffic: NAT gateways dominate, about
$33 each, so around $35 for dev or stage and $100 for prod with one per AZ.
Lambda, API Gateway, DynamoDB and CloudFront cost cents until there is
traffic.

## Security, since this repo is public

- No account ids and no credentials are committed. The keys in
  `emulator/aws-config` are placeholders the emulator reads as account
  numbers.
- State buckets get versioning, default encryption and a full public access
  block, and use S3 native locking (`use_lockfile`), no DynamoDB table.
- CI holds no secrets and reads the repo with `contents: read` only. Every
  action is pinned to a commit SHA and checkout does not persist the token.
- The API function's data access is `PutItem` and `Scan` on its own table,
  and its security group only allows HTTPS out to the DynamoDB prefix list.

## The emulator

[Floci](https://github.com/floci-io/floci) runs Lambda in real containers,
serves CloudFront and API Gateway on local hostnames, and gives each 12-digit
access key its own isolated account. I first tried AWS's own
[AWS Emulator](https://github.com/aws/aws-emulator), but today it fails on
security groups in a custom VPC
([#46](https://github.com/aws/aws-emulator/issues/46)) and on S3 buckets with
AWS provider 6.23 or later
([#56](https://github.com/aws/aws-emulator/issues/56)). Switching is a change
to `emulator/aws-config` and `scripts/emulator.sh`.

What an emulator does not prove: IAM policies are not enforced, routes and
NAT are API state rather than real packets, and the bill is not real.

Gaps I hit and how the code deals with them:

- CloudFront serves viewer requests from the emulator's default account
  only. `emulator.sh up <env>` sets the default to that environment, and CI
  runs one emulator per environment.
- The VPC endpoint service list has no DynamoDB entry, so the VPC module
  names gateway endpoints directly (`com.amazonaws.<region>.<service>`),
  which works the same on AWS.
- Flow log destination options are dropped
  ([floci#7888](https://github.com/floci-io/floci/issues/7888)), so S3 flow
  logs would be replaced on every plan. Flow logs go to CloudWatch Logs
  until that is fixed.
- S3 Control calls put the account id in front of the hostname, hence the
  `localhost.floci.io` endpoint, whose subdomains all resolve to 127.0.0.1.
