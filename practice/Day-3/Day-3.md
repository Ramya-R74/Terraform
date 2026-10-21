# Terraform Day 3 --- State, Lifecycle, Iteration, and S3 Remote Backend

This hands-on project covers Terraform state, drift, `for_each`
vs. `count`, lifecycle meta-arguments, provider version constraints, and
moving Terraform state to an Amazon S3 backend.

## Project goals

-   Understand Terraform state and drift.
-   Create environment-specific files using `for_each`.
-   Compare `for_each` with `count`.
-   Practice `create_before_destroy`, `prevent_destroy`, and
    `ignore_changes`.
-   Configure an S3 backend with native S3 state locking.
-   Use a named AWS CLI profile and least-privilege IAM permissions.
-   Troubleshoot AWS credential, S3 permission, and lifecycle errors.

## Concepts learned

### Terraform state and drift

Terraform state maps configuration to the resources Terraform manages.
Terraform uses it to plan updates, replacements, and deletions. State
can contain sensitive values, so it should not be committed to Git.

``` powershell
terraform state list
terraform state show 'local_file.environment_config["dev"]'
terraform show
terraform plan
terraform plan -refresh=false
```

`-refresh=false` skips refreshing remote objects before planning and can
produce a less accurate plan. Use it as a diagnostic option, not as a
normal replacement for refresh.

### `for_each` vs. `count`

The project uses a map of environment profiles (`dev`, `staging`, and
`prod`) to create one configuration file per environment.

``` hcl
resource "local_file" "environment_config" {
  for_each = var.profiles

  filename = "${path.module}/${each.key}-config.txt"
  content  = <<-EOT
    Environment: ${each.key}
    Application: ${each.value.application}
    Owner: ${each.value.owner}
    Log level: ${each.value.log_level}
  EOT
}
```

Terraform identifies these resources by their keys, for example
`local_file.environment_config["dev"]`. By contrast, `count` identifies
instances by numeric index, such as `example[0]`. `for_each` is usually
easier to maintain when resources have stable names or keys; changing
list order can cause confusing index changes with `count`.

### Lifecycle meta-arguments

``` hcl
lifecycle {
  create_before_destroy = true
}
```

When replacement is required and supported, Terraform attempts to create
the replacement before destroying the existing resource.

``` hcl
lifecycle {
  prevent_destroy = true
}
```

Terraform rejects plans that destroy this resource while the rule
remains in the configuration. It is a guardrail, not permanent
protection: removing the resource block also removes the rule.

``` hcl
lifecycle {
  ignore_changes = [content]
}
```

Terraform ignores changes to the specified attribute when planning
updates. This can be useful when another process manages that attribute,
but can also hide drift.

### Provider version constraints

``` hcl
required_providers {
  local = {
    source  = "hashicorp/local"
    version = "~> 2.0"
  }
}
```

`~> 2.0` permits compatible versions in the 2.x series. Commit
`.terraform.lock.hcl` to preserve the selected provider version and
checksums.

## Example project structure

``` text
terraform-day3-production-batch-provisioner/
├── backend.tf
├── main.tf
├── variables.tf
├── outputs.tf
├── .gitignore
├── .terraform.lock.hcl
└── README.md
```

The project creates local environment config files and includes a
`local_file.production_guard` resource for lifecycle experiments.

## S3 remote backend

### Backend values used

  Setting           Value
  ----------------- ----------------------------------------------
  Bucket            `terraform-demo-backend-21-10-2026`
  State key         `terraform-practice/day-3/terraform.tfstate`
  Region            `ap-south-1`
  AWS CLI profile   `terraform-demo`
  Encryption        `encrypt = true`
  Locking           `use_lockfile = true`

Verify that `ap-south-1` is the bucket's actual region.

### `backend.tf` backend block

Add this to your existing `terraform` block; don't create a second
`terraform` block.

``` hcl
terraform {
  required_version = ">= 1.10.0"

  backend "s3" {
    bucket       = "terraform-demo-backend-21-10-2026"
    key          = "terraform-practice/day-3/terraform.tfstate"
    region       = "ap-south-1"
    profile      = "terraform-demo"
    encrypt      = true
    use_lockfile = true
  }

  required_providers {
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}
```

Keep your existing resources and variables. The `profile` setting
chooses a configured AWS CLI profile; it is not a credential or a
permission grant.

### AWS CLI profile

``` powershell
aws configure --profile terraform-demo
aws sts get-caller-identity --profile terraform-demo
aws configure list --profile terraform-demo
```

Do not put access keys or secret keys in HCL. For human access, prefer
temporary credentials through IAM Identity Center when available.

### S3 object keys are not real folders

You do not need to create `terraform-practice/` or `day-3/` folders
manually. S3 stores objects by key, and the console displays prefixes as
folders. Terraform writes the state at
`terraform-practice/day-3/terraform.tfstate` when it has permission.

With `use_lockfile = true`, Terraform uses the temporary lock object
`terraform-practice/day-3/terraform.tfstate.tflock`, normally removing
it when the operation completes.

### Initialize the backend

If you are moving existing local state to S3:

``` powershell
terraform init -migrate-state
```

Review the prompt and confirm only when the bucket and key are correct.

If you intentionally want to reconfigure the backend without migrating
existing local state:

``` powershell
terraform init -reconfigure
```

These are different: `-migrate-state` attempts to copy state;
`-reconfigure` does not migrate it.

## Problems faced and how I solved them

### 1. AWS CLI returned an invalid token

**Symptom:** `aws sts get-caller-identity` returned an invalid-token
error.

**Troubleshooting:**

``` powershell
aws configure list --profile terraform-demo
aws configure list-profiles
aws sts get-caller-identity --profile terraform-demo
```

**Resolution:** Check which profile and credential source are active,
then refresh or correct the credentials for that profile. For an IAM
Identity Center profile, sign in again with
`aws sso login --profile <profile-name>`. For this demo, consistently
use the `terraform-demo` profile.

### 2. S3 backend returned 403 for `HeadObject`

**Symptom:**

``` text
Unable to access object "terraform-practice/day-3/terraform.tfstate"
in S3 bucket "terraform-demo-backend-21-10-2026":
S3 HeadObject ... StatusCode: 403
```

**Cause investigated:** The IAM policy's object key did not match the
backend key. An earlier example used `day3/dev/terraform.tfstate`, while
Terraform was accessing `terraform-practice/day-3/terraform.tfstate`.

**Resolution:** - Match the bucket, region, and key in the backend
configuration. - Allow `s3:GetObject` and `s3:PutObject` on the exact
state object. - Allow `s3:GetObject`, `s3:PutObject`, and
`s3:DeleteObject` on the exact `.tflock` object. - Allow `s3:ListBucket`
on the bucket with a prefix condition for the state and lock keys. - If
403 persists, inspect the bucket policy, permissions boundary,
organization SCP, and KMS permissions if a customer-managed key is used.

**Lesson:** Creating S3 folders does not fix a 403. Check permissions
and bucket restrictions; avoid solving it by granting `s3:*` or
`AdministratorAccess`.

### 3. Wondered whether S3 folders needed to be created

**Resolution:** No. S3 folder-like paths are prefixes in object keys.
Terraform can create the state object at the configured key once access
is correct.

### 4. Wondered whether IAM credentials belong in HCL

**Resolution:** Credentials stay outside `.tf` files. Set
`profile = "terraform-demo"` in the backend to select the named profile.
IAM policies determine permissions; the profile setting does not grant
access.

### 5. `prevent_destroy` blocked deletion of `local_file.production_guard`

**Symptom:**

``` text
local_file.production_guard has lifecycle.prevent_destroy set,
but the plan calls for this resource to be destroyed.
```

**Cause:** The resource had:

``` hcl
lifecycle {
  prevent_destroy = true
}
```

**Resolution for an intentional demo deletion:** 1. Temporarily set
`prevent_destroy = false` or remove the lifecycle rule. 2. Run
`terraform plan` and verify only the intended resource/file will be
deleted. 3. Run `terraform apply` after reviewing the plan.

Alternatively, remove the resource block from configuration and then
plan/apply the proposed deletion. `terraform destroy` does not bypass
`prevent_destroy`. `terraform state rm` only removes Terraform's
tracking and does not delete the actual file.

### 6. Confusion between `-migrate-state` and `-reconfigure`

**Resolution:** Use `terraform init -migrate-state` to move existing
local state to S3. Use `terraform init -reconfigure` when deliberately
switching backend configuration without migrating the previous state.
Check the bucket, key, region, and profile first.

## Useful commands

  --------------------------------------------------------------------------------------------
  Task                                Command
  ----------------------------------- --------------------------------------------------------
  Verify AWS identity                 `aws sts get-caller-identity --profile terraform-demo`

  Check credential source             `aws configure list --profile terraform-demo`

  Format files                        `terraform fmt -recursive`

  Validate configuration              `terraform validate`

  Initialize backend                  `terraform init`

  Migrate local state                 `terraform init -migrate-state`

  Reconfigure without migration       `terraform init -reconfigure`

  Preview changes                     `terraform plan`

  Apply changes                       `terraform apply`

  List tracked resources              `terraform state list`

  Inspect state                       `terraform show`
  --------------------------------------------------------------------------------------------

Test access to the specific state object:

``` powershell
aws s3api head-object `
  --bucket terraform-demo-backend-21-10-2026 `
  --key terraform-practice/day-3/terraform.tfstate `
  --profile terraform-demo
```

A `404` can indicate that the state object does not exist yet. A `403`
indicates denied access or that the caller cannot determine whether the
object exists.

## Security and best practices

-   Don't use root credentials for Terraform.
-   Prefer temporary credentials for human access.
-   Use a dedicated identity with least-privilege permissions.
-   Scope S3 access to the required state and lock object ARNs.
-   Enable S3 versioning and keep the bucket private.
-   Enable encryption and use separate state keys for
    projects/environments.
-   Treat state files as sensitive.
-   Never commit `.terraform/`, `*.tfstate`, `*.tfstate.*`, credentials,
    or secret-bearing `.tfvars` files.
-   Commit `.terraform.lock.hcl`.
-   Review plans carefully before applying deletions.
-   S3 storage and requests may incur AWS charges.

Example `.gitignore`:

``` gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfstate.backup
*.tfvars
*.tfvars.json
*.tfplan
tfplan
crash.log
crash.*.log
```

Do not ignore `.terraform.lock.hcl`.

## Key takeaways

1.  State helps Terraform track managed resources and calculate changes.
2.  `for_each` is useful for keyed resources; `count` uses numeric
    indices.
3.  Lifecycle rules control replacements, ignored changes, and deletion
    protection.
4.  `prevent_destroy` blocks deletion while the rule remains in the
    resource configuration.
5.  S3 backend configuration stores state remotely but does not grant
    permissions.
6.  The AWS profile provides credentials; IAM policies define what those
    credentials can do.
7.  S3 prefixes look like folders but do not need to be created
    manually.
8.  A 403 requires checking the exact bucket/key, IAM policy, bucket
    policy, and encryption permissions.
9.  Use `terraform init -migrate-state` when moving existing local state
    to S3.

**Day 3 completed:** Practiced Terraform state, iteration, lifecycle
protections, and S3 remote state setup while troubleshooting AWS
credentials and permissions.
