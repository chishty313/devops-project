terraform {
  backend "azurerm" {
    resource_group_name  = "rg-devops-tfstate"
    storage_account_name = "tfstatedevops1783530332"
    container_name       = "tfstate"
    key                  = "dev.terraform.tfstate"
    # Auth uses the storage account key supplied via the ARM_ACCESS_KEY env var
    # (never committed). AAD data-plane auth isn't available because the account's
    # constrained Owner role cannot self-assign the Storage Blob Data role.
  }
}
