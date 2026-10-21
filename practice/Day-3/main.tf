# resource block that iterates the profile object to create diffrent config files. 
resource "local_file" "environment_config" {
  for_each = var.profiles

  filename = "${path.module}/${each.key}-config.txt"

  content = <<-EOT
    Environment: ${each.key}
    Application: ${each.value.application}
    Owner: ${each.value.owner}
    Log level: ${each.value.log_level}
  EOT

  lifecycle {
    create_before_destroy = true
  }
}

# A separate critical configuration for lifecycle protection
resource "local_file" "production_guard" {
  filename = "${path.module}/production-critical.txt"

  content = <<-EOT
    Environment: production
    Application: inventory-api
    Protected configuration: true
  EOT

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [content]
  }
}