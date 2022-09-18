# aws-tools.sh

## HOW TO USE

The `setup.sh` script automates the setup required immediately after opening an AWS account.  
It sets up an IAM policy to require MFA, an IAM Role for the switch role, and an S3 bucket for the Terraform backend, and so on.  
It is very convenient to run `setup.sh` from AWS CloudShell.  

```bash
# download setup.sh
curl --tlsv1.2 -LRSs https://raw.githubusercontent.com/ginokent/aws-tools.sh/HEAD/setup.sh -o ./setup.sh

# (STRONGLY RECOMMEND) check md5 checksum
md5 -q ./setup.sh
curl --tlsv1.2 -LRSs https://raw.githubusercontent.com/ginokent/aws-tools.sh/HEAD/setup.sh.md5

# run setup.sh
chmod +x ./setup.sh
./setup.sh
```

<!-- old docs
```bash
aws-vault exec $AWS_PROFILE -- sh -c "curl --tlsv1.2 -LRSs https://raw.githubusercontent.com/ginokent/aws-tools.sh/HEAD/aws-iam-create-policy-ManageOwnAccessKeys.sh | sh"
aws-vault exec $AWS_PROFILE -- sh -c "curl --tlsv1.2 -LRSs https://raw.githubusercontent.com/ginokent/aws-tools.sh/HEAD/aws-iam-create-policy-ManageOwnMFADevices.sh | sh"
```
-->
