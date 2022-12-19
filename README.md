# terraform-dms-postgres-to-s3

## Usage

### Deploy Terraform (/infra)

```shell
terraform validate
terraform fmt
terraform refresh
terraform init
terraform plan -out tfplan
terraform apply tfplan
terraform destroy
```

Powershell:
``` shell
.\scripts\deploy_dev.ps1
```

SH:
``` shell
TBC
```

### DBT

```
dbt debug
dbt run
dbt test
```


## Directories

### DBT (/data)

\models
\macros
\analyses
\dbt_packages
\snapshots
\seeds
\tests
\logs

\target\compiled
\target\run
