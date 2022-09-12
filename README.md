# aws-tools.sh

## HOW TO USE

```bash
aws-vault exec $AWS_PROFILE -- sh -c "curl -LRSs https://raw.githubusercontent.com/ginokent/aws-tools.sh/HEAD/aws-iam-create-policy-ManageOwnAccessKeys.sh | sh"
aws-vault exec $AWS_PROFILE -- sh -c "curl -LRSs https://raw.githubusercontent.com/ginokent/aws-tools.sh/HEAD/aws-iam-create-policy-ManageOwnMFADevices.sh | sh"
