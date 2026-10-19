# Day 2: Terraform Variables, Outputs, Dependencies & Data Sources

This document summarizes the Day 2 Terraform concepts, hands-on
examples, troubleshooting notes, and interview questions. It builds on
the Day 1 foundations of IaC, HCL syntax, providers, and the Terraform
workflow.

------------------------------------------------------------------------

## 📚 Table of Contents

1.  [Learning Objectives](#1-learning-objectives)
2.  [Input Variables](#2-input-variables)
3.  [Terraform Variable Types](#3-terraform-variable-types)
4.  [Supplying Variable Values](#4-supplying-variable-values)
5.  [Variable Precedence](#5-variable-precedence)
6.  [Interpolation and Resource
    References](#6-interpolation-and-resource-references)
7.  [Implicit and Explicit
    Dependencies](#7-implicit-and-explicit-dependencies)
8.  [Output Values](#8-output-values)
9.  [Data Sources](#9-data-sources)
10. [Hands-On Project: Dynamic
    Configurator](#10-hands-on-project-dynamic-configurator)
11. [Useful Commands](#11-useful-commands)
12. [Common Mistakes and
    Troubleshooting](#12-common-mistakes-and-troubleshooting)
13. [Interview Practice](#13-interview-practice)
14. [Quick Revision Checklist](#14-quick-revision-checklist)

------------------------------------------------------------------------

## 1. Learning Objectives

By the end of Day 2, you should be able to:

-   Make Terraform configurations reusable using input variables.
-   Choose appropriate primitive and complex variable types.
-   Provide different values without changing `.tf` files.
-   Understand which variable value Terraform selects when several
    sources provide a value.
-   Reference values from variables, resources, and data sources.
-   Explain implicit versus explicit dependencies.
-   Display useful information with output blocks.
-   Read information from existing resources or files using data
    sources.

------------------------------------------------------------------------

## 2. Input Variables

Input variables are parameters for a Terraform configuration. They help
avoid hardcoding values and make the same configuration reusable.

### Example: `variables.tf`

``` hcl
variable "filename" {
  description = "Name of the generated file"
  type        = string
  default     = "environment-config.txt"
}
```

### Using a variable

``` hcl
resource "local_file" "example" {
  filename = "${path.module}/${var.filename}"
  content  = "Created with Terraform"
}
```

**Key points:**

-   `variable` declares an input variable.
-   `type` restricts the kind of value accepted.
-   `default` provides a value when no higher-precedence value is
    supplied.
-   `var.filename` references the variable.
-   `path.module` is the filesystem path of the module containing the
    expression.

If a variable has no default and no value is supplied, Terraform
generally prompts for it in an interactive run, or reports that a
required value is missing in a non-interactive run.

------------------------------------------------------------------------

## 3. Terraform Variable Types

Terraform supports primitive types and complex types.

  ------------------------------------------------------------------------------------
  Type                    Example                              Typical use
  ----------------------- ------------------------------------ -----------------------
  `string`                `"dev"`                              Names, regions, file
                                                               paths

  `number`                `3`                                  Counts, sizes, numeric
                                                               settings

  `bool`                  `true`                               Feature toggles

  `list(string)`          `["dev", "test"]`                    Ordered collection of
                                                               strings

  `set(string)`           `["web", "api"]`                     Unique string values;
                                                               ordering is not
                                                               significant

  `map(string)`           `{ environment = "dev" }`            Key/value settings

  `object({...})`         `{ app = "api", version = "1.0" }`   Structured values with
                                                               named attributes

  `tuple([...])`          `["dev", 2, true]`                   Fixed-position values
                                                               with potentially
                                                               different types
  ------------------------------------------------------------------------------------

### Example declarations

``` hcl
variable "environment" {
  type    = string
  default = "dev"
}

variable "replica_count" {
  type    = number
  default = 2
}

variable "enable_logging" {
  type    = bool
  default = true
}

variable "file_prefixes" {
  type    = list(string)
  default = ["terraform", "day2"]
}

variable "environment_settings" {
  type = map(string)
  default = {
    environment = "dev"
    region      = "ap-south-1"
    owner       = "cloud-team"
  }
}

variable "app_metadata" {
  type = object({
    application = string
    version     = string
    owner       = string
  })

  default = {
    application = "inventory-api"
    version     = "1.0"
    owner       = "platform-team"
  }
}
```

### Accessing values

``` hcl
var.environment
var.environment_settings["environment"]
var.app_metadata.application
var.file_prefixes[0]
```

List indexes start at `0`, so `var.file_prefixes[0]` returns the first
item.

------------------------------------------------------------------------

## 4. Supplying Variable Values

Terraform supports several ways to supply variable values.

### A. Default value

Declared inside `variables.tf`:

``` hcl
variable "environment" {
  type    = string
  default = "dev"
}
```

### B. Automatically loaded `terraform.tfvars`

``` hcl
environment = "test"
```

Terraform automatically loads `terraform.tfvars` and
`terraform.tfvars.json` from the working directory.

### C. A named variable file

Create `test.tfvars`:

``` hcl
environment = "test"
```

Use it explicitly:

``` bash
terraform plan -var-file="test.tfvars"
terraform apply -var-file="test.tfvars"
```

### D. CLI variable

``` bash
terraform plan -var="environment=staging"
```

### E. Environment variable

PowerShell:

``` powershell
$env:TF_VAR_environment = "qa"
terraform plan
```

Remove it after the experiment:

``` powershell
Remove-Item Env:TF_VAR_environment
```

Bash / Git Bash:

``` bash
export TF_VAR_environment="qa"
terraform plan
unset TF_VAR_environment
```

Environment variables use the `TF_VAR_` prefix followed by the variable
name.

**Security note:** Do not commit secret-bearing `.tfvars` files or
credentials. Environment variables are not automatically a complete
secrets-management solution; avoid exposing secrets in shell history,
logs, or plans.

------------------------------------------------------------------------

## 5. Variable Precedence

When multiple sources set the same variable, Terraform uses a precedence
order. For the common sources used in this project, the order from lower
to higher precedence is:

1.  Variable `default`
2.  Environment variable (`TF_VAR_name`)
3.  `terraform.tfvars` and `terraform.tfvars.json`
4.  Automatically loaded `*.auto.tfvars` and `*.auto.tfvars.json` files,
    in lexical filename order
5.  Command-line `-var` and `-var-file` arguments, processed in
    command-line order

If multiple CLI arguments assign the same variable, the later assignment
takes precedence. Terraform's full precedence rules include details for
multiple files and command-line arguments, so consult the official
documentation for edge cases.

### Example experiment

Suppose these sources assign `filename`:

-   Default: `default.txt`
-   Environment variable: `env.txt`
-   `terraform.tfvars`: `tfvars.txt`
-   CLI: `cli.txt`

Run:

``` powershell
$env:TF_VAR_filename = "env.txt"
terraform plan -var="filename=cli.txt"
```

Expected selected value: `cli.txt`.

The original variable files are not edited by this command.

**Remember:** `-var` and `-var-file` only affect that Terraform
invocation. The next command uses the values supplied to that next
invocation.

------------------------------------------------------------------------

## 6. Interpolation and Resource References

Terraform expressions allow values to flow from one part of a
configuration to another.

### Reference a variable

``` hcl
filename = "${path.module}/${var.environment}-marker.txt"
```

If `var.environment` is `"dev"`, the resulting path ends in
`dev-marker.txt`.

Modern Terraform also allows direct expression syntax when the whole
value is an expression:

``` hcl
filename = "${path.module}/${var.environment}-marker.txt"
```

String templates use `${...}` to embed expressions inside strings.

### Reference a resource attribute

``` hcl
resource "random_pet" "pet" {
  length = 2
}

resource "local_file" "pet_file" {
  filename = "${path.module}/${random_pet.pet.id}.txt"
  content  = "Generated pet: ${random_pet.pet.id}"
}
```

`random_pet.pet.id` refers to the `id` attribute of the `random_pet`
resource named `pet`.

This reference both supplies the value and establishes an implicit
dependency.

------------------------------------------------------------------------

## 7. Implicit and Explicit Dependencies

Terraform builds a dependency graph to determine a safe execution order.

### Implicit dependency

A dependency Terraform detects from a reference:

``` hcl
resource "random_pet" "pet" {
  length = 2
}

resource "local_file" "pet_file" {
  filename = "${path.module}/${random_pet.pet.id}.txt"
  content  = "Pet: ${random_pet.pet.id}"
}
```

The file needs the generated pet name, so Terraform creates the pet
resource before creating the file.

### Explicit dependency

Use `depends_on` when a dependency exists but Terraform cannot infer it
from a reference:

``` hcl
resource "local_file" "deployment_marker" {
  filename = "${path.module}/${var.environment}-marker.txt"
  content  = "Preparing ${var.environment}"
}

resource "local_file" "deployment_config" {
  filename = "${path.module}/${var.environment}-config.txt"
  content  = "Configuration for ${var.environment}"

  depends_on = [local_file.deployment_marker]
}
```

Terraform creates the marker before the deployment configuration.

**Best practice:** Prefer implicit dependencies through meaningful
references. Use `depends_on` only when necessary; unnecessary explicit
dependencies can restrict Terraform's ability to schedule operations
efficiently.

------------------------------------------------------------------------

## 8. Output Values

Output blocks expose useful values after Terraform operations. They can
show resource attributes, paths, generated names, and other expressions.

### Example: `outputs.tf`

``` hcl
output "generated_pet_name" {
  description = "Generated random pet name"
  value       = random_pet.pet.id
}

output "configuration_file_path" {
  description = "Path of the generated file"
  value       = local_file.pet_file.filename
}
```

Useful commands:

``` bash
terraform output
terraform output generated_pet_name
terraform output -json
```

Output values may be displayed in terminal logs and CI output. Do not
expose secrets through outputs. Marking an output `sensitive = true`
redacts it in some normal CLI displays, but does not remove the value
from Terraform state.

------------------------------------------------------------------------

## 9. Data Sources

A data source reads information about an existing object rather than
managing its lifecycle as a resource.

### Example: Read an existing local file

First, create `external-info.txt` manually:

``` text
This information is maintained outside Terraform.
Owner: Cloud Engineering Team.
```

Then add this to `main.tf`:

``` hcl
data "local_file" "external_info" {
  filename = "${path.module}/external-info.txt"
}
```

Use the content in another resource:

``` hcl
resource "local_file" "environment_config" {
  filename = "${path.module}/environment-config.txt"

  content = <<-EOT
    Environment: ${var.environment}
    External information:
    ${data.local_file.external_info.content}
  EOT
}
```

### Resource vs data source

  -----------------------------------------------------------------------
  Resource                            Data source
  ----------------------------------- -----------------------------------
  Manages an object's lifecycle       Reads information about an existing
                                      object

  Declared using `resource`           Declared using `data`

  Example:                            Example: `data "local_file" ...`
  `resource "local_file" ...`         

  Terraform can create, update, or    The data source reads the source
  delete the managed file             file; it does not create or manage
                                      that source file
  -----------------------------------------------------------------------

A data source may be read during planning or apply, depending on whether
its inputs are known and whether dependencies defer the read.

------------------------------------------------------------------------

## 10. Hands-On Project: Dynamic Configurator

**Project name:** `terraform-day2-dynamic-configurator`

### Objective

Create an environment-specific configuration file that combines input
variables, a random pet name, and content read from an external file.

### Suggested structure

``` text
terraform-day2-dynamic-configurator/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── outputs.tf
├── external-info.txt
└── .gitignore
```

### Core requirements

1.  Declare a `map(string)` for environment settings.
2.  Declare a `list(string)` for file prefixes.
3.  Declare an `object` for application metadata.
4.  Use `terraform.tfvars` to supply example values.
5.  Use `random_pet` to generate a pet name.
6.  Use `data "local_file"` to read `external-info.txt`.
7.  Use resource references to include the pet name and external content
    in a generated file.
8.  Use `depends_on` to demonstrate explicit ordering where appropriate.
9.  Create output blocks for the pet name, file path, and file content.
10. Test variable precedence using a default, environment variable,
    `.tfvars` file, and CLI override.

### Example variable definitions

``` hcl
variable "environment_settings" {
  type = map(string)
  default = {
    environment = "dev"
    region      = "ap-south-1"
    owner       = "cloud-team"
  }
}

variable "file_prefixes" {
  type    = list(string)
  default = ["terraform", "day2", "config"]
}

variable "app_metadata" {
  type = object({
    application = string
    version     = string
    owner       = string
  })

  default = {
    application = "inventory-api"
    version     = "1.0"
    owner       = "platform-team"
  }
}
```

### Validation workflow

``` bash
terraform init
terraform fmt
terraform validate
terraform plan
terraform apply
terraform output
```

After reviewing the result, modify a variable and run `terraform plan`
again. Explain why Terraform proposes any changes before applying them.

### GitHub hygiene

Keep `.terraform.lock.hcl` in version control for reproducible provider
selection. Add these patterns to `.gitignore`:

``` gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfvars.json
*.tfplan
crash.log
crash.*.log
```

Do not ignore `.terraform.lock.hcl`. Only commit example variable files
if they contain no secrets. Avoid committing generated state, saved
plans, credentials, or secret-bearing variable files.

------------------------------------------------------------------------

## 11. Useful Commands

  -----------------------------------------------------------------------
  Command                             Purpose
  ----------------------------------- -----------------------------------
  `terraform init`                    Initialize the working directory
                                      and install providers

  `terraform fmt`                     Format Terraform files

  `terraform validate`                Validate configuration syntax and
                                      internal consistency

  `terraform plan`                    Preview proposed changes

  `terraform apply`                   Apply changes after review

  `terraform output`                  Display outputs

  `terraform show`                    Inspect current state or a saved
                                      plan

  `terraform state list`              List resources tracked in state

  `terraform graph`                   Generate a dependency graph in DOT
                                      format

  `terraform destroy`                 Destroy resources managed by the
                                      current configuration
  -----------------------------------------------------------------------

For this local-file project, `terraform destroy` can delete
Terraform-managed output files. Review the plan and back up anything you
want to keep.

------------------------------------------------------------------------

## 12. Common Mistakes and Troubleshooting

### Mistake 1: Map key does not exist

Incorrect:

``` hcl
var.environment_settings["env"]
```

If the map key is `environment`, use:

``` hcl
var.environment_settings["environment"]
```

Map keys must match exactly.

### Mistake 2: Variable is not declared

If Terraform reports that a variable is undeclared, define it in a `.tf`
file using a `variable` block and reference it with `var.variable_name`.

### Mistake 3: External file does not exist

If `data.local_file.external_info` cannot read the file, check the path
and create `external-info.txt` before running the data source.

### Mistake 4: Changes do not appear as expected

Run:

``` bash
terraform fmt
terraform validate
terraform plan
```

Confirm which variable source is winning, and inspect the proposed plan
before applying it.

### Mistake 5: Random value changes unexpectedly

The random provider generally retains a generated result in state until
the resource must be replaced or its relevant configuration changes. Do
not assume every plan creates a new random value.

### Mistake 6: `.gitignore` does not untrack a state file

`.gitignore` prevents new untracked matching files from being added
automatically. It does not remove files already tracked by Git. If state
was committed, remove it from tracking and address any sensitive data
that may have entered repository history.

------------------------------------------------------------------------

## 13. Interview Practice

### Q1. Why do we use Terraform input variables?

**Answer:** Input variables make Terraform configurations reusable and
configurable. They allow users to supply different values without
editing the underlying resource definitions.

### Q2. What is the difference between `variables.tf` and `terraform.tfvars`?

**Answer:** `variables.tf` declares variable names, types, descriptions,
and optional defaults. `terraform.tfvars` supplies values for those
variables.

### Q3. What is variable precedence?

**Answer:** Variable precedence determines which supplied value
Terraform uses when the same variable is assigned through multiple
sources. CLI variable arguments generally override automatically loaded
variable files, which override environment variables and defaults.

### Q4. What is the difference between a resource and a data source?

**Answer:** A resource manages an object's lifecycle. A data source
reads information about an existing object without managing that
object's lifecycle.

### Q5. What is the difference between implicit and explicit dependencies?

**Answer:** Terraform detects implicit dependencies from references
between resources. Explicit dependencies use `depends_on` to declare
ordering when Terraform cannot infer the dependency from references.

### Q6. What does `random_pet.pet.id` mean?

**Answer:** It references the `id` attribute of the `random_pet`
resource whose local Terraform name is `pet`.

### Q7. What are Terraform output values used for?

**Answer:** Outputs expose selected values from a configuration, such as
generated resource attributes, file paths, or identifiers. They can be
displayed in the CLI and consumed by other Terraform configurations.

### Q8. What is the difference between `list`, `set`, and `map`?

**Answer:** A list is ordered and indexed; a set contains unique values
without meaningful ordering; a map stores values accessed by keys.

### Q9. What happens when you change a variable used in a resource filename?

**Answer:** Terraform recalculates the desired filename and compares it
with the managed object in state. Depending on the resource provider's
behavior, it may update or replace the resource. Review `terraform plan`
to confirm the actual action.

### Q10. Does `terraform plan` modify infrastructure?

**Answer:** Its primary purpose is to preview proposed changes rather
than apply them. Planning can still refresh state or query providers, so
it is not a guarantee that absolutely nothing changes outside the
configuration.

### Scenario-based questions

1.  A teammate changes `terraform.tfvars`, but a CLI `-var` argument
    still supplies the old value. Why?
2.  A data source fails because a file is missing. How would you
    diagnose and fix it?
3.  Two resources must execute in a particular order, but no direct
    attribute reference connects them. What would you use, and why?
4.  Your generated file contains an unexpected environment name. How
    would you identify which variable source supplied the value?
5.  A teammate accidentally commits a Terraform state file. What are
    your immediate steps to protect any exposed sensitive information?

### Practical interview challenge

Without copying the example configuration, create a Terraform project
that:

-   Accepts an environment name and application metadata.
-   Generates a random pet name.
-   Reads a pre-existing text file.
-   Creates an output file using variable values and the generated name.
-   Displays the output file path and generated name.
-   Demonstrates variable precedence.
-   Explains the dependency graph.

Be prepared to explain every block and diagnose at least one intentional
error.

------------------------------------------------------------------------

## 14. Quick Revision Checklist

Before moving to Day 3, confirm that you can:

-   [ ] Declare typed input variables.
-   [ ] Use strings, numbers, booleans, lists, maps, and objects.
-   [ ] Supply values through defaults, `.tfvars`, environment
    variables, and CLI arguments.
-   [ ] Explain variable precedence.
-   [ ] Use interpolation and resource attribute references.
-   [ ] Explain implicit and explicit dependencies.
-   [ ] Declare and query output values.
-   [ ] Read an existing file using a data source.
-   [ ] Read a plan and explain why Terraform proposes a change.
-   [ ] Keep state, secrets, and generated artifacts out of GitHub.

**Day 2 takeaway:** Variables make configurations reusable, references
connect values and create implicit dependencies, `depends_on` declares
dependencies Terraform cannot infer, outputs expose useful results, and
data sources read existing information.
