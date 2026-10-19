variable "filename"{
    description = " Name of the generated configuration file"
    type = string  
    default = "env-configuration.txt"
}

variable "env_setting"{
    description = " Environment setting to be used in the configuration file"
    type = map(string)  
    default = {
        env = "Test"
        region = "us-west-1"
        owner = "cloud-team"
    }
}

variable "file_prefix"{
    description = " Prefix to be used in the generated configuration file"
    type = list(string)
    default = ["terraform","config"]
}

variable "app_metadata"{
    description = " Application metadata to be used in the configuration file"
    type = object({
    application = string
    version     = string
    owner       = string
  })

  default = {
    application = "test-api"
    version     = "1.0"
    owner       = "cloud-team"
  }
}

# string: the filename.
# map(string): environment settings accessed using keys.
# ist(string): an ordered collection of prefixes.
# object: a structured group of application properties.