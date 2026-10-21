
variable "profiles" {
  description = "Configuration profiles to generate"
  type = map(object({
    application = string
    owner       = string
    log_level   = string
  }))

  default = {
    dev = {
      application = "inventory-api"
      owner       = "development-team"
      log_level   = "DEBUG"
    }

    QA = {
      application = "inventory-api"
      owner       = "qa-team"
      log_level   = "INFO"
    }

    prod = {
      application = "inventory-api"
      owner       = "platform-team"
      log_level   = "WARN"
    }
  }
}
