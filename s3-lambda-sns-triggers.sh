#!/bin/bash

###############
# Author : K PRANAY REDDY
# Date   : 15-03-2024
#
# This script creates a S3-bucket, Lambda Function, IAM role .Simple-notification-service (sns)
# and a event triggerer i.e whenever there is a data addition to bucket lambda function is called/triggered
# which tries to send info through sns. 
###############


# Runs the script in debug mode
set -x

# Retrieving the account id of the caller and storing it 
aws_account_id=$(aws sts get-caller-identity --query 'Account' --output text)

# Print the AWS account ID from the variable
echo "AWS Account ID: $aws_account_id"

# Assigning names to resources
aws_region="us-east-1"  #set a region here or have a default one by using --aws configure  
bucket_name="pranay-ultimate-bucket"  #assign unique name for each bucket
lambda_func_name="s3-lambda-function"
role_name="s3-lambda-sns"
topic_name="s3-lambda-sns"
email_address="example@gmail.com" #the subscription mail-id (change it) 

# Create IAM Role for the project and adding who can assume this role 
role_response=$(aws iam create-role --role-name s3-lambda-sns --assume-role-policy-document '{
  "Version": "2012-10-17",
  "Statement": [{
    "Action": "sts:AssumeRole",
    "Effect": "Allow",
    "Principal": {
      "Service": [
         "lambda.amazonaws.com",
         "s3.amazonaws.com",
         "sns.amazonaws.com"
      ]
    }
  }]
}')

# Printing the output
echo "Role-response : $role_response"

# Extracting the Role ARN from the Json Response
role_arn=$(echo "$role_response" | jq -r '.Role.Arn')   #ARN helps to identify resource uniquely


# Printing the Role Arn
echo "Role ARN: $role_arn"

# Attaching the permissions(Lambda,Sns) to the Role
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AWSLambda_FullAccess
aws iam attach-role-policy --role-name $role_name --policy-arn arn:aws:iam::aws:policy/AmazonSNSFullAccess

# Create S3 bucket and storing the output
bucket_output=$(aws s3api create-bucket --bucket "$bucket_name" --region "$aws_region")

# Print the output
echo "Bucket creation output: $bucket_output"

# Uploading a image to the bucket
aws s3 cp ./aws-event-triggering.png s3://"$bucket_name"/aws-event-triggering.png

# Zipping of files to create a lambda function
zip -r s3-lambda-function.zip ./s3-lambda-function

sleep 5

# Creation of lambda function
aws lambda create-function \
  --region "$aws_region" \
  --function-name $lambda_func_name \
  --runtime "python3.8" \
  --handler "s3-lambda-function/s3-lambda-function.lambda_handler" \
  --memory-size 128 \
  --timeout 30 \
  --role "arn:aws:iam::$aws_account_id:role/$role_name" \
  --zip-file "fileb://./s3-lambda-function.zip"

# Adding permission such that lambda accepts the S3 bucket's invoke
aws lambda add-permission \
  --region "$aws_region" \
  --function-name "$lambda_func_name" \
  --statement-id "s3-lambda-sns" \
  --action "lambda:InvokeFunction" \
  --principal s3.amazonaws.com \
  --source-arn "arn:aws:s3:::$bucket_name"

# Creating an S3 event trigger for the lambda function
LambdaFunctionArn="arn:aws:lambda:us-east-1:$aws_account_id:function:s3-lambda-function"
aws s3api put-bucket-notification-configuration \
  --region "$aws_region" \
  --bucket "$bucket_name" \
  --notification-configuration '{
    "LambdaFunctionConfigurations": [{
        "LambdaFunctionArn": "'"$LambdaFunctionArn"'",
        "Events": ["s3:ObjectCreated:*"]
    }]
}'

# Create an SNS topic and save the topic ARN to a variable
topic_arn=$(aws sns create-topic --name $topic_name --region $aws_region --output json | jq -r '.TopicArn')

# Print the TopicArn
echo "SNS Topic ARN: $topic_arn"


# Subscribes an email address to the topic on accepting
aws sns subscribe \
  --topic-arn "$topic_arn" \
  --protocol email \
  --notification-endpoint "$email_address"



















