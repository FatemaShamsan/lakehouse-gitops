# Lakehouse GitOps on minikube

Mirrors your company's EKS pattern: **Argo CD** deploys everything from Git, **Envoy Gateway** is the ingress,
**Kyverno** enforces policy. **AWS is simulated with LocalStack** (S3, KMS, Secrets Manager, IAM), and the AWS
resources are created with **OpenTofu**, as you would on real AWS. On top: an Iceberg REST catalog, Trino and a Spark job.
Nothing here touches real AWS.

**Status: written but not run on a real cluster.** Chart versions use `*` (latest) or a version I could not
verify. If a sync fails, open the app in Argo CD, read the error, and pin a version you have checked.

## LocalStack licence note
Since March 2026 the newest LocalStack images need a free account and an auth token (the free Hobby plan is for
non-commercial use; check whether learning on a work laptop counts). This repo pins version 4.14, which I
understand was the last one without that requirement, but it no longer gets updates. To use a newer image, change the
tag in `manifests/aws-local/localstack.yaml` and run `LOCALSTACK_AUTH_TOKEN=... ./localstack-token.sh`.
Limits: LocalStack does not enforce IAM policies, and EKS, Glue, Athena and Lake Formation are not covered well.

## You need
OpenTofu (`tofu`) as well as the tools below.
Docker, minikube, kubectl, git, and a GitHub repo you can push to. Give minikube about 10 GB RAM if you can
(`MEMORY=8192` works but is tight). Spark and Trino are the heavy parts.

## Steps
1. Create an empty GitHub repo, for example `lakehouse-gitops`. Copy this folder into it and push to `main`.
2. `REPO_URL=https://github.com/<you>/lakehouse-gitops.git ./bootstrap.sh`
   It starts minikube, installs Argo CD, rewrites `REPO_URL` in the app files, and waits for you to push that
   change. Then it applies the root app.
3. Watch it sync: `kubectl -n argocd port-forward svc/argocd-server 8080:443`, open https://localhost:8080,
   user `admin`, password printed by the script. You should see: envoy-gateway, kyverno, lakehouse-manifests, trino.
4. Create the "AWS" resources in LocalStack: `./aws-local.sh` (needs OpenTofu). This makes the `warehouse` bucket,
   a KMS key, a secret and an IAM role. **Do this before step 5**, because the pipeline writes to that bucket.
5. Run the pipeline: `./jobs/run-pipeline.sh` (Bronze, Silver, quarantine).
6. Query: `./jobs/access.sh shell`, then
   `SELECT * FROM lakehouse.silver.orders;` (3 rows) and `SELECT * FROM lakehouse.silver.orders_quarantine;` (2 rows).
7. Through the gateway: `./jobs/access.sh gateway`, then http://trino.localtest.me:8081 .
8. See the policy report: `kubectl get policyreport -A` . MinIO and the catalog use `:latest`, so they show as
   violations. Pin their tags, push, then change the policy to `Enforce`.

## How this maps to the company cluster
| Company | Here |
| --- | --- |
| EKS | minikube |
| Argo CD, Envoy Gateway, Kyverno | Same tools, same flow |
| S3, KMS, Secrets Manager, IAM | LocalStack (created with OpenTofu) |
| Aurora PostgreSQL | Not needed yet (add a PostgreSQL pod for Airflow or Superset) |
| Pod Identity, Secrets Manager | Demo credentials in Secrets. Replace with External Secrets later |
| Karpenter spot pool | Optional: `minikube start --nodes 3`, label a node `pool=spot`, add a nodeSelector to the Spark job |
| Entra ID | Skip, or Keycloak later |
| ECR, GitHub Actions | Public images here. Later: build images in GitHub Actions |

## Next
Add Airflow, dbt, Superset and Grafana by adding one file each to `apps/` (same pattern as `20-trino.yaml`).
Replace the REST catalog with Polaris. LocalStack uses `emptyDir`, so if its pod restarts you lose the bucket:
run `./aws-local.sh` again and rerun the pipeline.
