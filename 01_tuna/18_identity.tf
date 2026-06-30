resource "azurerm_user_assigned_identity" "vmss_kv_identity" {
  name = "tuna-vmss-kv-identity"
  resource_group_name = var.rgname
  location            = var.loca1

  depends_on = [
    azurerm_resource_group.tuna_rg
  ]
}