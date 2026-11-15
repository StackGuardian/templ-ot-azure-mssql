# Tests

Tests use the built-in OpenTofu test framework (`tofu test`, OpenTofu 1.12 or later).

| Level | Folder | What it does | Cost | When it runs |
|---|---|---|---|---|
| Unit | `tests/unit` | Plan only with mocked providers. Checks configuration and security settings. | None | Merge requests into `development` or `main`, and tags |
| Integration | `tests/integration` | Deploys real resources, checks them, destroys them. | Cloud cost while running | Tags, when cloud credentials are set (`integration-tests` job) |

In the GitLab pipeline, the `unit-tests` job also publishes the results as a JUnit test report (**Tests** tab of the pipeline and of the merge request). The script `ci/tofu-json-to-junit.py` converts the output of `tofu test -json` to JUnit XML.

## Run locally

```bash
tofu init
tofu test -test-directory=tests/unit
tofu test -test-directory=tests/integration   # needs cloud credentials
```

## Test cases

| ID | Level | Description | Status |
|---|---|---|---|
| U-01 | Unit | Default variables produce a valid plan with all default tags | done |
| U-02 | Unit | Invalid `name_prefix` is rejected | done |
| U-03 | Unit | Custom `tags` are merged with the default tags | done |
| U-04 | Unit | Public network access is disabled, minimum TLS 1.2 | done |
| U-05 | Unit | Private endpoint (`sqlServer`) in the endpoint subnet, private DNS zone linked to the VNet, NSG allows 1433 only from the VNet | done |
| U-06 | Unit | Admin password only through write-only arguments, secret has an expiry date, Key Vault uses RBAC | done |
| U-07 | Unit | The deployer is the Entra ID admin, SQL logins stay enabled | done |
| U-08 | Unit | Point-in-time restore is 7 days by default, transparent data encryption is on | done |
| U-09 | Unit | Backup retention above 7 days on Basic is rejected | done |
| U-10 | Unit | Server auditing, database logs and Key Vault audit logs go to Log Analytics | done |
| U-11 | Unit | Serverless SKU pauses after 60 minutes with a minimum of 0.5 vCores | done |
| U-12 | Unit | Default is a 2 GB Basic database without serverless settings | done |
| U-13 | Unit | Basic with more than 2 GB is rejected | done |
| U-14 | Unit | Unknown SKU is rejected | done |
| U-15 | Unit | Reserved administrator login `admin` is rejected | done |
| U-16 | Unit | System database name `master` is rejected | done |
| U-17 | Unit | A size the DTU SKU does not offer (32 GB on S0) is rejected | done |
| I-01 | Integration | Server and database are created and the server has an FQDN | done |
| I-02 | Integration | Private endpoint connection to the server is approved | done |
| I-03 | Integration | Admin password secret exists in Key Vault (value is not read) | done |

Integration tests are written but have not run against a real cloud account yet.
