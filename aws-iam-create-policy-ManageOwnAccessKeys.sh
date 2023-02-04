#!/bin/sh
# LISENCE: https://github.com/ginokent/aws-tools.sh/blob/HEAD/LICENSE

# NOTE: ref. Managing access keys for IAM users https://docs.aws.amazon.com/IAM/latest/UserGuide/id_credentials_access-keys.html
tee /tmp/ManageOwnAccessKeys.json <<"POLICY"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ManageOwnAccessKeys",
      "Effect": "Allow",
      "Action": [
        "iam:CreateAccessKey",
        "iam:DeleteAccessKey",
        "iam:GetAccessKeyLastUsed",
        "iam:GetUser",
        "iam:ListAccessKeys",
        "iam:UpdateAccessKey"
      ],
      "Resource": "arn:aws:iam::*:user/${aws:username}"
    }
  ]
}
POLICY

sh -cx "aws --output json iam create-policy --policy-name ManageOwnAccessKeys --policy-document file:///tmp/ManageOwnAccessKeys.json"
