locals {
  creation_statement    = [for e in var.json_data.entitlements : e.creation_statement if e.role == var.role_name][0]
  approved_users        = [for e in var.json_data.entitlements : e.approvedusers if e.role == var.role_name][0]
}

data "vault_identity_group" "user" {
  for_each = toset(local.approved_users)
  group_name = each.value
}

locals {
  member_group_ids = [for  v in data.vault_identity_group.user: "${v.id}"]
}

resource "vault_database_secret_backend_role" "db_role" {
  backend               = var.backend_path
  name                  = var.role_name
  db_name               = var.db_name
  creation_statements   = ["CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT SELECT ON *.* TO '{{name}}'@'%';"]
}

resource "vault_policy" "db_role_policy" {
  name      = "${var.backend_path}-${var.role_name}"
  policy    = <<EOT
  path "${var.backend_path}/creds/${var.role_name}" {
    capabilities = ["read"]
  }
  EOT
}

resource "vault_identity_group" "db_role_group" {
  name                        = "${var.backend_path}-${var.role_name}"
  type                        = "internal"
  external_member_entity_ids  = true
  metadata = {
    version = "2"
  }

  external_policies = true
  member_group_ids = local.member_group_ids

  depends_on = [
    vault_policy.db_role_policy
  ]
}

resource "vault_identity_group_policies" "policies" {
  policies = [
    "${var.backend_path}-${var.role_name}",
  ]
  group_id = vault_identity_group.db_role_group.id
  depends_on = [
    vault_policy.db_role_policy
  ]
}
