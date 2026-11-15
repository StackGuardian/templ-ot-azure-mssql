# Azure SQL Database

Creates an Azure SQL Database that is reachable only from a private network through a private endpoint. The admin password is generated during the run and stored in Azure Key Vault. It never appears in the state.

Use it when an application or a demo needs a secure Microsoft SQL Server database on Azure.

## What gets created

- A resource group
- A virtual network with a subnet for the private endpoint and a network security group
- A logical SQL server with public access turned off, and one database
- A private endpoint and a private DNS zone, so the server name resolves to a private IP inside the network
- A Key Vault with the admin password
- A Log Analytics workspace with server audit logs, database logs and Key Vault audit logs

## Before you start

- A workflow with an Azure cloud connector for the target subscription
- The connector's identity needs rights to create resources **and** to assign roles (for example Owner, or Contributor plus User Access Administrator). It gets access to the Key Vault during the run and becomes the Entra ID admin of the server
- A plan for how clients reach the database: they must run inside this network
- OpenTofu 1.12.0 or newer, if you run the module outside StackGuardian. The StackGuardian template uses 1.13.9. Older versions fail on the write-only password

## Form fields

| Field | What it does | Default |
|---|---|---|
| Name prefix | Prefix for all resource names. 2 to 16 lowercase letters, digits or hyphens, starting with a letter | `demo` |
| Location | Azure region | Germany West Central |

**Advanced Settings** (tick "Show advanced settings" to change them):

| Field | What it does | Default |
|---|---|---|
| VNet cidr | IP range of the new network | `10.0.0.0/16` |
| SKU | Size of the database: Basic, Standard S0 to S2, General Purpose serverless (pauses after an hour without connections) or General Purpose with 2 or 4 vCores | Basic |
| Max size in GB | Maximum size of the database. Basic allows up to 2 GB, the others up to 250 GB in this form | `2` |
| Database name | Name of the database | `app` |
| Administrator login | Name of the admin user. Names like admin, sa or root are not allowed | `sqladmin` |
| Password version | Raise this number and run again to create a new admin password | `1` |
| Backup retention days | How many days of point-in-time restore are kept, 1 to 35 (Basic: up to 7) | `7` |
| Log retention days | How long logs are kept, 30 to 730 days | `90` |
| Tags | Extra tags added to all resources | none |

If the size or the backup retention does not fit the SKU, the run stops with a message before anything is created. Not every SKU is available in every region. If the run fails for that reason, pick another SKU or region.

## After the run

The workflow outputs show:

- `server_fqdn` and `database_name`: the connection details. The address resolves to the private IP only inside the network
- `private_endpoint_ip`: the private IP address of the server
- `administrator_login`, `key_vault_id` and `admin_password_secret_name`: read the password from the Key Vault, for example in the Azure portal
- `resource_group_name` and `vnet_id`: deploy your clients into this network

Creating everything takes about 5 to 10 minutes.

## Security defaults

- No public access. Port 1433 is open only inside the network, through the private endpoint
- TLS 1.2 or higher is required, data is encrypted at rest (transparent data encryption)
- The password is never written to the state. In Key Vault it expires after one year
- Point-in-time restore is on
- Server auditing, database logs and Key Vault audit logs go to Log Analytics

## Cost and cleanup

Basic and Standard databases are billed per hour, also when idle. Serverless databases bill compute only while active and storage all the time. The private endpoint and log ingestion are billed as well. Destroy the resources from the workflow when the demo is over.

## Limits

- No access from outside the network
- Single database without zone redundancy or geo-replication
- No Microsoft Defender for SQL (vulnerability assessment and threat alerts), as it is billed per server
