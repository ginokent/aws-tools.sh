#!/bin/sh
# https://github.com/ginokent/aws-tools.sh

aws_account_id=${AWS_ACCOUNT_ID-$(aws --output text sts get-caller-identity --query Account)}
bucket_name=terraform-backend-${aws_account_id:?}-${AWS_REGION:?}

sh -cx "aws --output json s3 mb s3://${bucket_name:?} --region ${AWS_REGION:?}"

sh -cx "aws s3api put-bucket-versioning --bucket ${bucket_name:?} --versioning-configuration Status=Enabled"
sh -cx "aws s3api get-bucket-versioning --bucket ${bucket_name:?}"

sh -cx "aws s3api put-public-access-block --bucket ${bucket_name:?} --public-access-block-configuration 'BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true'"
sh -cx "aws s3api get-public-access-block --bucket ${bucket_name:?}"
