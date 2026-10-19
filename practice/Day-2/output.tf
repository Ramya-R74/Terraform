
output "configuration_file_path" {
  description = "Path to the generated configuration file"
  value       = local_file.env_configuration.filename
}

output "configuration_file_content" {
  description = "Content of the generated configuration file"
  value       = local_file.env_configuration.content
}

output "external_source_content" {
  description = "Content read from the external file"
  value       = data.local_file.external_info.content
}
