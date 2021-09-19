region = "ap-southeast-2"
environment_variables_map = {
  THUMBNAIL_BASE_URL = "https://my-terraform-module-bucket.s3.ap-southeast-2.amazonaws.com/thumbnail"
  S3_BUCKET_NAME     = "my-terraform-module-bucket"
  BROKER_TYPE        = "sqs"
  QUEUE_NAME         = "celery-queue-testing"
  AWS_DEFAULT_REGION = "ap-southeast-2"
}
