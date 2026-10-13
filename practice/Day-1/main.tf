resource "local_file" "My_pet" {
  filename        = "${path.module}/${random_pet.pet.id}"
  file_permission = "0744"
  content         = " Hello! Randomly generated petname is ${random_pet.pet.id}"
}

resource "random_pet" "pet" {
  length = var.pet_name_length
}