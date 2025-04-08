# workshop-cndro-2025
Code used for Cloud Native Days Romania Amazon EKS Autoscaling Workshop

## Prerequisites

1. [AWS Account](https://aws.amazon.com/free)
2. [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) with the following configuration:
   - Create a profile called `amcloud` with the following command:
     ```bash
     aws configure --profile amcloud
     ```
   - Enter the following details when prompted:
     - AWS Access Key ID: `<AWS_ACCESS_KEY_ID>`
     - AWS Secret Access Key: `<AWS_SECRET_ACCESS_KEY>`
     - Default region name: `eu-central-1`
     - Default output format: `text`
   - The configuration will look like this in `~/.aws/config`: 
     ```ini
     [profile amcloud]
     region = eu-central-1
     output = text
     ```
3. [AWS S3 Bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/creating-bucket.html) can be created using the AWS CLI with the following command:
    ```bash
    aws s3 create-bucket --bucket <BUCKET_NAME> --region <REGION>
    ```
4. [Terraform](https://www.terraform.io/downloads.html)
5. [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
6. [Helm](https://helm.sh/docs/intro/install/)
