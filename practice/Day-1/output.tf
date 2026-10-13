output "pet_name" {
  description = "randomly generated pet name"
  value       = random_pet.pet.id
}

output "pet_file_path" {
  description = "path to the file where the pet details stored"
  value       = local_file.My_pet.filename
}
