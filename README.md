# Wiz technical exercise – two-tier app on AWS

Containerised to-do app (tasky) on Amazon EKS, backed by MongoDB on an EC2 VM,
built with Terraform and deployed by GitHub Actions.

> **Warning:** this environment is deliberately insecure (outdated OS and database,
> SSH open to the internet, over-permissive IAM role, public backup bucket,
> cluster-admin workload) for a security exercise. Do not reuse it.

- `app/` – application source, Dockerfile, wizexercise.txt
- `terraform/` – all AWS infrastructure
- `k8s/` – Kubernetes manifests
- `.github/workflows/` – CI/CD pipelines