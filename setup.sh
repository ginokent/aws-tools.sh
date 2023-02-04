#!/usr/bin/env bash
# LISENCE: https://github.com/ginokent/aws-tools.sh/blob/HEAD/LICENSE
set -Eeu -o pipefail

# LISENCE: https://github.com/kunitsuinc/rec.sh/blob/HEAD/LICENSE
# Common
if [ -t 2 ]; then REC_COLOR=true; else REC_COLOR=''; fi
_recRFC3339() { date "+%Y-%m-%dT%H:%M:%S%z" | sed "s/\(..\)$/:\1/"; }
_recCmd() { for a in "$@"; do if echo "${a:-}" | grep -Eq "[[:blank:]]"; then printf "'%s' " "${a:-}"; else printf "%s " "${a:-}"; fi; done | sed "s/ $//"; }
# Color
RecDefault() { test "  ${REC_SEVERITY:-0}" -gt 000 2>/dev/null || echo "$*" | awk "{print   \"$(_recRFC3339) [${REC_COLOR:+\\033[0;35m}  DEFAULT${REC_COLOR:+\\033[0m}] \"\$0\"\"}" 1>&2; }
RecDebug() { test "    ${REC_SEVERITY:-0}" -gt 100 2>/dev/null || echo "$*" | awk "{print   \"$(_recRFC3339) [${REC_COLOR:+\\033[0;34m}    DEBUG${REC_COLOR:+\\033[0m}] \"\$0\"\"}" 1>&2; }
RecInfo() { test "     ${REC_SEVERITY:-0}" -gt 200 2>/dev/null || echo "$*" | awk "{print   \"$(_recRFC3339) [${REC_COLOR:+\\033[0;32m}     INFO${REC_COLOR:+\\033[0m}] \"\$0\"\"}" 1>&2; }
RecNotice() { test "   ${REC_SEVERITY:-0}" -gt 300 2>/dev/null || echo "$*" | awk "{print   \"$(_recRFC3339) [${REC_COLOR:+\\033[0;36m}   NOTICE${REC_COLOR:+\\033[0m}] \"\$0\"\"}" 1>&2; }
RecWarning() { test "  ${REC_SEVERITY:-0}" -gt 400 2>/dev/null || echo "$*" | awk "{print   \"$(_recRFC3339) [${REC_COLOR:+\\033[0;33m}  WARNING${REC_COLOR:+\\033[0m}] \"\$0\"\"}" 1>&2; }
RecError() { test "    ${REC_SEVERITY:-0}" -gt 500 2>/dev/null || echo "$*" | awk "{print   \"$(_recRFC3339) [${REC_COLOR:+\\033[0;31m}    ERROR${REC_COLOR:+\\033[0m}] \"\$0\"\"}" 1>&2; }
RecCritical() { test " ${REC_SEVERITY:-0}" -gt 600 2>/dev/null || echo "$*" | awk "{print \"$(_recRFC3339) [${REC_COLOR:+\\033[0;1;31m} CRITICAL${REC_COLOR:+\\033[0m}] \"\$0\"\"}" 1>&2; }
RecAlert() { test "    ${REC_SEVERITY:-0}" -gt 700 2>/dev/null || echo "$*" | awk "{print   \"$(_recRFC3339) [${REC_COLOR:+\\033[0;41m}    ALERT${REC_COLOR:+\\033[0m}] \"\$0\"\"}" 1>&2; }
RecEmergency() { test "${REC_SEVERITY:-0}" -gt 800 2>/dev/null || echo "$*" | awk "{print \"$(_recRFC3339) [${REC_COLOR:+\\033[0;1;41m}EMERGENCY${REC_COLOR:+\\033[0m}] \"\$0\"\"}" 1>&2; }
RecExec() { RecInfo "$ $(_recCmd "$@")" && "$@"; }
RecRun() { _dlm="####R#E#C#D#E#L#I#M#I#T#E#R####" _all=$({ _out=$("$@") && _rtn=$? || _rtn=$? && printf "\n%s" "${_dlm:?}${_out:-}" && return ${_rtn:-0}; } 2>&1) && _rtn=$? || _rtn=$? && _dlmno=$(echo "${_all:-}" | sed -n "/${_dlm:?}/=") && _cmd=$(_recCmd "$@") && _stdout=$(echo "${_all:-}" | tail -n +"${_dlmno:-1}" | sed "s/^${_dlm:?}//") && _stderr=$(echo "${_all:-}" | head -n "${_dlmno:-1}" | grep -v "^${_dlm:?}") && RecInfo "$ ${_cmd:-}" && { [ -z "${_stdout:-}" ] || RecInfo "${_stdout:?}"; } && { [ -z "${_stderr:-}" ] || RecWarning "${_stderr:?}"; } && return ${_rtn:-0}; }
# export functions for bash
# shellcheck disable=SC3045
echo "${SHELL-}" | grep -q bash$ && export -f _recRFC3339 _recCmd RecDefault RecDebug RecInfo RecWarning RecError RecCritical RecAlert RecEmergency RecExec RecRun

# var
aws_account_id=${AWS_ACCOUNT_ID-$(aws --output text sts get-caller-identity --query Account)}
terraform_backent_bucket_name=terraform-backend-${aws_account_id:?}-${AWS_REGION:?}

#
# IAM
#

RecInfo "Setup IAM"

if ! { aws iam get-policy --policy-arn "arn:aws:iam::${aws_account_id:?}:policy/ManageOwnAccessKeys" --query Policy.IsAttachable --output text 2>&1 | grep -q ^True; }; then
  RecNotice "Create arn:aws:iam::${aws_account_id:?}:policy/ManageOwnAccessKeys"
  RecExec tee /tmp/ManageOwnAccessKeys.json <<"POLICY"
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
  RecExec aws iam create-policy --policy-name ManageOwnAccessKeys --policy-document file:///tmp/ManageOwnAccessKeys.json --output json
fi

if ! { aws iam get-policy --policy-arn "arn:aws:iam::${aws_account_id:?}:policy/ManageOwnMFADevices" --query Policy.IsAttachable --output text 2>&1 | grep -q ^True; }; then
  RecNotice "Create arn:aws:iam::${aws_account_id:?}:policy/ManageOwnMFADevices"
  RecExec tee /tmp/ManageOwnMFADevices.json <<"POLICY"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "AllowListActions",
      "Effect": "Allow",
      "Action": [
        "iam:ListUsers",
        "iam:ListVirtualMFADevices"
      ],
      "Resource": "*"
    },
    {
      "Sid": "AllowIndividualUserToListOnlyTheirOwnMFA",
      "Effect": "Allow",
      "Action": [
        "iam:ListMFADevices"
      ],
      "Resource": [
        "arn:aws:iam::*:mfa/*",
        "arn:aws:iam::*:user/${aws:username}"
      ]
    },
    {
      "Sid": "AllowIndividualUserToManageTheirOwnMFA",
      "Effect": "Allow",
      "Action": [
        "iam:CreateVirtualMFADevice",
        "iam:DeleteVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:ResyncMFADevice"
      ],
      "Resource": [
        "arn:aws:iam::*:mfa/${aws:username}",
        "arn:aws:iam::*:user/${aws:username}"
      ]
    },
    {
      "Sid": "AllowIndividualUserToDeactivateOnlyTheirOwnMFAOnlyWhenUsingMFA",
      "Effect": "Allow",
      "Action": [
        "iam:DeactivateMFADevice"
      ],
      "Resource": [
        "arn:aws:iam::*:mfa/${aws:username}",
        "arn:aws:iam::*:user/${aws:username}"
      ],
      "Condition": {
        "Bool": {
          "aws:MultiFactorAuthPresent": "true"
        }
      }
    },
    {
      "Effect": "Allow",
      "Action": "iam:GetAccountPasswordPolicy",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "iam:ChangePassword",
      "Resource": "arn:aws:iam::*:user/${aws:username}"
    },
    {
      "Sid": "BlockMostAccessUnlessSignedInWithMFA",
      "Effect": "Deny",
      "NotAction": [
        "iam:CreateVirtualMFADevice",
        "iam:EnableMFADevice",
        "iam:ListMFADevices",
        "iam:ListUsers",
        "iam:ListVirtualMFADevices",
        "iam:ResyncMFADevice",
        "iam:ChangePassword",
        "iam:GetAccountPasswordPolicy"
      ],
      "Resource": "*",
      "Condition": {
        "BoolIfExists": {
          "aws:MultiFactorAuthPresent": "false"
        }
      }
    }
  ]
}
POLICY
  RecExec aws iam create-policy --policy-name ManageOwnMFADevices --policy-document file:///tmp/ManageOwnMFADevices.json --output json
fi

if ! { aws iam get-role --role-name AdministratorRole >/dev/null 2>&1; }; then
  RecNotice "Create arn:aws:iam::${aws_account_id:?}:role/AdministratorRole"
  if [[ -z ${IAM_USERS-} ]]; then
    RecError "Set the IAM ARNs separated by commas in environment variable \"IAM_USERS\""
    exit 1
  fi
  iam_users="${IAM_USERS:?}"
  RecNotice "use env IAM_USERS: ${iam_users:?}"
  iam_users=$(
    echo "${iam_users:?}" |
      tr , "\n" |
      while read -r IAM_USER || [ -n "${IAM_USER-}" ]; do
        echo "                  \"${IAM_USER:?}\","
      done
  )
  RecExec tee /tmp/AdministratorRole.json <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [
${iam_users-}
                  "arn:aws:iam::${aws_account_id:?}:root"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
  RecExec aws --output json iam create-role --role-name AdministratorRole --assume-role-policy-document file:///tmp/AdministratorRole.json
fi

if ! { aws iam list-attached-role-policies --role-name AdministratorRole --query AttachedPolicies[].PolicyName --output text 2>&1 | grep -q AdministratorAccess; }; then
  RecNotice "Attach policies to arn:aws:iam::${aws_account_id:?}:role/AdministratorRole"
  RecExec aws --output json iam attach-role-policy --role-name AdministratorRole --policy-arn "arn:aws:iam::aws:policy/AdministratorAccess"
fi

if ! { aws iam get-role --role-name ReadOnlyRole >/dev/null 2>&1; }; then
  RecNotice "Create arn:aws:iam::${aws_account_id:?}:role/ReadOnlyRole"
  if [[ -z ${IAM_USERS-} ]]; then
    RecError "Set the IAM ARNs separated by commas in environment variable \"IAM_USERS\""
    exit 1
  fi
  iam_users="${IAM_USERS:?}"
  RecNotice "use env IAM_USERS: ${iam_users:?}"
  iam_users=$(
    echo "${iam_users:?}" |
      tr , "\n" |
      while read -r IAM_USER || [ -n "${IAM_USER-}" ]; do
        echo "                  \"${IAM_USER:?}\","
      done
  )
  RecExec tee /tmp/ReadOnlyRole.json <<POLICY
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "AWS": [
${iam_users-}
                  "arn:aws:iam::${aws_account_id:?}:root"
                ]
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
POLICY
  RecExec aws --output json iam create-role --role-name ReadOnlyRole --assume-role-policy-document file:///tmp/ReadOnlyRole.json
fi

if ! { aws iam list-attached-role-policies --role-name ReadOnlyRole --query AttachedPolicies[].PolicyName --output text 2>&1 | grep -q ReadOnlyAccess; }; then
  RecNotice "Attach policies to arn:aws:iam::${aws_account_id:?}:role/ReadOnlyRole"
  RecExec aws --output json iam attach-role-policy --role-name ReadOnlyRole --policy-arn "arn:aws:iam::aws:policy/ReadOnlyAccess"
fi

RecNotice "Please setup ~/.aws/config like below:"
RecNotice "$(awk '{print "    "$0}' <(
  cat <<DOT_AWS_CONFIG
---
[profile SWITCH_SOURCE_PROFILE]
region = ${AWS_REGION:?}
mfa_serial = arn:aws:iam::${aws_account_id:?}:mfa/SOURCE_IAMUSER
credential_process = aws-vault exec SWITCH_SOURCE_PROFILE --json --prompt=osascript

# for ReadOnly
[profile READONLY_PROFILE]
region = ${AWS_REGION:?}
mfa_serial = arn:aws:iam::${aws_account_id:?}:mfa/SOURCE_IAMUSER
role_arn = arn:aws:iam::SWITCH_SOURCE_AWS_ACCOUNT_ID:role/ReadOnlyRole
source_profile = SWITCH_SOURCE_PROFILE

# for Administrator
[profile ADMINISTRATOR_PROFILE]
region = ${AWS_REGION:?}
mfa_serial = arn:aws:iam::${aws_account_id:?}:mfa/SOURCE_IAMUSER
role_arn = arn:aws:iam::SWITCH_SOURCE_AWS_ACCOUNT_ID:role/AdministratorRole
source_profile = SWITCH_SOURCE_PROFILE
---
DOT_AWS_CONFIG
))"

#
# S3
#

RecInfo "Setup S3"

if ! { aws s3 ls "s3://${terraform_backent_bucket_name:?}" >/dev/null 2>&1; }; then
  RecNotice "Create s3://${terraform_backent_bucket_name:?}"
  RecExec aws s3 mb "s3://${terraform_backent_bucket_name:?}" --region "${AWS_REGION:?}" --output json
fi

if ! { aws s3api get-bucket-versioning --bucket "${terraform_backent_bucket_name:?}" --query Status --output text 2>&1 | grep -q ^Enabled; }; then
  RecNotice "Put bucket-versioning s3://${terraform_backent_bucket_name:?}"
  RecExec aws s3api put-bucket-versioning --bucket "${terraform_backent_bucket_name:?}" --versioning-configuration Status=Enabled
  RecExec aws s3api get-bucket-versioning --bucket "${terraform_backent_bucket_name:?}"
fi

if [ "$(aws s3api get-public-access-block --bucket "${terraform_backent_bucket_name:?}" --query PublicAccessBlockConfiguration --output text 2>&1 | grep -o True | grep -c True)" != 4 ]; then
  RecNotice "Put public-access-block s3://${terraform_backent_bucket_name:?}"
  RecExec aws s3api put-public-access-block --bucket "${terraform_backent_bucket_name:?}" --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'
  RecExec aws s3api get-public-access-block --bucket "${terraform_backent_bucket_name:?}"
fi
