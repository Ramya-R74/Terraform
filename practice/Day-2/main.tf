# Read an existing external text file
data "local_file" "external_info" {
  filename = "${path.module}/external-info.txt"
}

# Create a marker file first
resource "local_file" "deployment_marker" {
  filename = "${path.module}/${var.env_setting["env"]}-config-marker.txt"
  content = "Preparing configuration for ${var.app_metadata.application}"
}

# Generate the environment configuration
resource "local_file" "env_configuration" {
  filename = "${path.module}/${var.filename}"

  content = <<-EOT
    Environment: ${var.env_setting["env"]}
    Region: ${var.env_setting["region"]}
    Owner: ${var.env_setting["owner"]}

    Application: ${var.app_metadata.application}
    Version: ${var.app_metadata.version}
    Metadata owner: ${var.app_metadata.owner}

    File prefixes: ${join(", ", var.file_prefix)}

    Source information:
    ${data.local_file.external_info.content}
  EOT

  # Explicit dependency: create the marker first
  depends_on = [local_file.deployment_marker]
}
