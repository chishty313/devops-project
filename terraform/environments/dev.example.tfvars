# Copy this to dev.tfvars and fill in real values (dev.tfvars is gitignored).
subscription_id = "<your-azure-subscription-id>"
location        = "eastus"
environment     = "dev"
project         = "devops"

node_count = 2
node_size  = "Standard_B2s"

# Least-privilege defaults are "Network Contributor" / "AcrPull". Override to
# "Owner" only if your account can't assign non-Owner roles (constrained Owner).
# cluster_network_role = "Owner"
# kubelet_acr_role     = "Owner"
