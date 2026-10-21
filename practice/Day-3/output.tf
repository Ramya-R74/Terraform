
output "generated_environment_files" {
  description = "Paths of the generated environment configuration files"
  value = {
    for env, file in local_file.environment_config :
    env => file.filename
  }
}

output "production_guard_path" {
  description = "Path of the protected production configuration"
  value       = local_file.production_guard.filename
}
