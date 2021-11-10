provider "vault" {
  namespace = "engineering"
}

resource "vault_mount" "db1" {
  path = "db1"
  type = "database"
}


resource "vault_database_secret_backend_connection" "mysql" {
  backend       = vault_mount.db1.path
  name          = "mysql"
  allowed_roles = ["*"]
  mysql {
    connection_url    = "root:test123@tcp(localhost:3306)/"
    username_template = "{{.DisplayName | replace \"@hashicorp.com\" \"\" }}-{{.RoleName}}-{{random 8}}"
  }
}



locals {
  raw_data = jsondecode(file("${path.module}/role-assignments.json"))
  roles    = local.raw_data.entitlements[*].role
}

module "main" {
  source   = "./modules/dbroleentitypolicy"
  for_each = toset(local.roles)

  json_data    = local.raw_data
  role_name    = each.key
  backend_path = vault_mount.db1.path
  db_name      = vault_database_secret_backend_connection.mysql.name
}


