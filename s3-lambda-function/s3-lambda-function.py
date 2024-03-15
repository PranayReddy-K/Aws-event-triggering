import boto3
import json

def lambda_handler(event, context):
    
    # Extracting relevant information from tthe s3 event trigger
    bucket_name = event['Records'][0]['s3']['bucket']['name']
    object_key = event['Records'][0]['s3']['object']['key']
    
    # Logs the details
    print(f"File '{object_key}' was uploaded to bucket '{bucket_name}'")
    
    # Retrieve the account id rather than hard-coding
    sts_client = boto3.client('sts')
    caller_identity = sts_client.get_caller_identity()
    aws_account_id = caller_identity['Account']
    
    # Lambda function should send a notification
    sns_client = boto3.client('sns')
    topic_arn = f'arn:aws:sns:us-east-1:{aws_account_id}:s3-lambda-sns'
    sns_client.publish(
       TopicArn=topic_arn,
       Subject='S3 Object Created',
       Message=f"File '{object_key}' was uploaded to bucket '{bucket_name}'"
    )
    
    # We can also invoke another lambda function from this (i.e) another trigger if needed
    
    # To send everything was successful
    return {
        'statusCode': 200,
        'body': json.dumps('Lambda function executed successfully')
    }
    