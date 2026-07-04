# Future Improvement Proposal (Task 7)

Each improvement follows: **what** is recommended, **why** it's needed, **how** it helps
the team/business, **how** it would be implemented, and **what risk** it reduces.

## 1. Secret management with Azure Key Vault
- **What:** back Kubernetes Secrets with Azure Key Vault via the Secrets Store CSI driver.
- **Why:** today the DB password lives in a Kubernetes Secret (base64 in etcd) and in
  Terraform state; Key Vault centralizes secrets with access policies, versioning, and audit.
- **How it helps:** one source of truth, automatic rotation, full audit trail; developers
  never see raw secrets.
- **How:** enable the CSI driver add-on, store secrets in Key Vault, mount them via a
  `SecretProviderClass`, use workload identity for pod-to-Key-Vault auth.
- **Risk reduced:** secret leakage and unrotated, unaudited credentials.

## 2. Image vulnerability scanning
- **What:** scan images in CI and in the registry (Trivy in the pipeline, ACR/Defender scanning).
- **Why:** base images and dependencies accumulate CVEs (our frontend build already flags
  npm vulnerabilities).
- **How it helps:** catches vulnerable images before they ship; continuous registry scanning
  catches newly-disclosed CVEs in already-pushed images.
- **How:** add a Trivy step that fails the build on HIGH/CRITICAL; enable Microsoft Defender
  for Containers on ACR.
- **Risk reduced:** deploying known-exploitable code.

## 3. Monitoring and alerting
- **What:** Prometheus + Grafana (or Azure Monitor managed Prometheus) with alert rules.
- **Why:** Log Analytics collects data, but there are no proactive alerts today.
- **How it helps:** the team learns about problems before users do (pod restarts, high error
  rate, cert expiry, node pressure).
- **How:** deploy kube-prometheus-stack, define alert rules, route to Slack/PagerDuty; add
  dashboards for the golden signals.
- **Risk reduced:** silent failures and slow incident response.

## 4. Rollback strategy
- **What:** automated rollback on failed deploys.
- **Why:** a bad image should not stay live; manual rollback is slow.
- **How it helps:** faster recovery, higher availability.
- **How:** keep image history (SHA tags — already done), use `kubectl rollout undo`, add a
  smoke-test gate in CD that auto-rolls-back on failure; adopt Argo Rollouts for automated analysis.
- **Risk reduced:** prolonged outages from a bad release.

## 5. Helm chart
- **What:** package the k8s manifests as a Helm chart (or Kustomize overlays).
- **Why:** raw YAML is duplicated across environments and hard to parameterize.
- **How it helps:** one templated chart with per-env values; easier upgrades and rollbacks.
- **How:** convert manifests to a chart with `values-dev/staging/prod.yaml`; render image
  tags and replicas from values.
- **Risk reduced:** config drift and copy-paste errors between environments.

## 6. Terraform remote backend hardening (already partly done)
- **What:** we already use Azure Storage remote state with locking; add state encryption
  key management, restricted network access, and per-environment state files.
- **Why:** state contains sensitive data and must be protected and isolated.
- **How it helps:** safe collaboration, no accidental cross-env changes.
- **How:** private-endpoint the storage account, separate state keys per env, least-privilege
  RBAC on the container.
- **Risk reduced:** state corruption, leakage, and cross-environment blast radius.

## 7. Kubernetes autoscaling
- **What:** Horizontal Pod Autoscaler + Cluster Autoscaler.
- **Why:** fixed replicas/nodes waste money at low load and fail under spikes.
- **How it helps:** matches capacity to demand automatically; saves cost and improves resilience.
- **How:** add HPA on CPU/memory (metrics-server is available), enable the AKS cluster
  autoscaler on the node pool with min/max.
- **Risk reduced:** outages under load and overspend at idle.

## 8. Cluster upgrade strategy
- **What:** a defined, tested upgrade cadence with surge and PDBs.
- **Why:** clusters fall out of support; ad-hoc upgrades are risky.
- **How it helps:** predictable, low-risk upgrades; stay on supported versions.
- **How:** upgrade control plane then node pools with `max_surge`, PodDisruptionBudgets,
  and a staging rehearsal; consider AKS auto-upgrade channels.
- **Risk reduced:** unsupported versions and upgrade-induced downtime.

## 9. Production approval gates
- **What:** manual approval + protected environments for production deploys.
- **Why:** production changes should be reviewed and deliberate.
- **How it helps:** prevents accidental prod deploys; adds an audit point.
- **How:** GitHub Environments with required reviewers on the `prod` deploy job.
- **Risk reduced:** unreviewed, accidental production releases.

## 10. Private cluster
- **What:** make the AKS API server private.
- **Why:** the API server is currently public.
- **How it helps:** removes a public attack surface for the control plane.
- **How:** `private_cluster_enabled = true`, access via VPN/bastion/private endpoint.
- **Risk reduced:** control-plane exposure to the internet.

## 11. Web Application Firewall (WAF)
- **What:** put Azure Application Gateway + WAF (or Front Door) in front of the ingress.
- **Why:** the app is directly internet-facing with no L7 filtering.
- **How it helps:** blocks OWASP Top 10 attacks, bots, and DDoS at the edge.
- **How:** deploy App Gateway WAF, route traffic to the ingress, enable OWASP rule set.
- **Risk reduced:** common web exploits reaching the app.

## 12. GitOps with Argo CD
- **What:** deploy via Argo CD watching the repo instead of `kubectl` from CI.
- **Why:** push-based CD lets state drift; the cluster isn't guaranteed to match git.
- **How it helps:** git is the single source of truth, with drift detection and easy rollback.
- **How:** install Argo CD, point Applications at the k8s/ (or Helm) path, auto-sync.
- **Risk reduced:** configuration drift and untracked manual changes.

## 13. Blue/green or canary deployment
- **What:** progressive delivery instead of a straight rolling update.
- **Why:** a rolling update still exposes all users to a bad version briefly.
- **How it helps:** validate a new version on a slice of traffic before full rollout.
- **How:** Argo Rollouts or two Services + ingress weighting; automated metric analysis.
- **Risk reduced:** blast radius of a bad release.

## 14. Backup and disaster recovery
- **What:** back up the database and cluster state; document an RTO/RPO and DR runbook.
- **Why:** there's no backup of the VM-based DB today.
- **How it helps:** recover from data loss or a regional outage.
- **How:** scheduled `pg_dump`/managed backups to geo-redundant storage, Velero for cluster
  resources, and a tested restore procedure.
- **Risk reduced:** permanent data loss and unrecoverable outages.

## 15. Network policies
- **What:** Kubernetes NetworkPolicies (Azure network policy is already enabled) to restrict
  pod-to-pod traffic.
- **Why:** by default any Pod can talk to any Pod.
- **How it helps:** limits lateral movement if a Pod is compromised.
- **How:** default-deny in the namespace, then allow frontend→backend and backend→DB only.
- **Risk reduced:** lateral movement and over-broad internal access.

## 16. Cost optimization
- **What:** right-size nodes, use spot node pools for non-critical workloads, set budgets/alerts.
- **Why:** dev clusters run costly SKUs 24/7 if not managed (we mitigate by stopping/destroying).
- **How it helps:** meaningful savings without hurting reliability.
- **How:** cluster autoscaler, spot pools with tolerations, `az aks stop` off-hours, Azure
  Budgets + Cost alerts, reserved instances for steady prod.
- **Risk reduced:** budget overruns.
