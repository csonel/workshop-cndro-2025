# workshop-cndro-2025
Code used for Cloud Native Days Romania Amazon EKS Autoscaling Workshop

## Prerequisites

1. [AWS Account](https://aws.amazon.com/free)
2. [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) with the following configuration:
   - Create a profile called `cndro2025` with the following command:
     ```bash
     aws configure --profile cndro2025
     ```
   - Enter the following details when prompted:
     - AWS Access Key ID: `<AWS_ACCESS_KEY_ID>`
     - AWS Secret Access Key: `<AWS_SECRET_ACCESS_KEY>`
     - Default region name: `eu-central-1`
     - Default output format: `text`
   - The configuration will look like this in `~/.aws/config`:
     ```ini
     [profile cndro2025]
     region = eu-central-1
     output = text
     ```
3. [AWS S3 Bucket](https://docs.aws.amazon.com/AmazonS3/latest/userguide/creating-bucket.html) for storing terraform state.
   It can be created using the AWS CLI with the following command:
   ```bash
   aws s3 create-bucket --bucket <BUCKET_NAME> --region <REGION>
   ```
4. [Terraform](https://www.terraform.io/downloads.html)
5. [Kubectl](https://kubernetes.io/docs/tasks/tools/#kubectl)
6. [Helm](https://helm.sh/docs/intro/install/)

## Workshop Steps

1. **Create the EKS Cluster**:
   - Navigate to the root directory and run the following command:
     ```bash
     terraform init
     terraform apply
     ```
   - This will create an EKS cluster with the specified configuration in `terraform.tfvars`
   - It will also configure `kubectl` to use the EKS cluster

2. **Install Kube Ops View**
   - Run the following command to install Kube Ops View:
     ```bash
     kubectl create namespace kube-ops-view
     kubectl apply -f ./kube-ops-view-deployment

     kubectl get pod -n kube-ops-view
     ```
   - This will deploy Kube Ops View in the `kube-ops-view` namespace
   - You can access Kube Ops View using port forwarding:
     ```bash
     kubectl port-forward -n kube-ops-view service/kube-ops-view 8080:80
     ```
     Then, open your browser and navigate to `http://localhost:8080`

3. **Deploy a Sample App**
   - Run the following command to deploy an application and expose as a service on TCP port 80:
     ```bash
     kubectl create deployment php-apache --image=eu.gcr.io/k8s-artifacts-prod/hpa-example
     kubectl set resources deployment php-apache --requests=cpu=200m,memory=128Mi
     kubectl expose deployment php-apache --port=80

     kubectl get pod -l app=php-apache
     ```
   - The application is a custom-built image based on the php-apache image. The index.php page performs calculations to generate CPU load.
   More information can be found [here](https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/#run-expose-php-apache-server)
   - Create an HPA resource. This HPA scales up when CPU exceeds 50% of the allocated container resources
     ```bash
     kubectl autoscale deployment php-apache --cpu-percent=50 --min=1 --max=10

     kubectl get hpa
     ```
     View the HPA using kubectl. You probably will see `<unknown>/50%` for 1-2 minutes and then you should be able to see `0%/50%`

4. **Configure Cluster Autoscaler (CA)**
   - Prepare your environment for the Cluster Autoscaler. First, we will need to create AWS IAM role to be used by CA.
   For that, we will need to open `terraform.tfvars` and set the following variables:
     ```hcl
     enable_eks_cluster_autoscaler = true
     ```
     After that, we will need to run terraform again:
     ```bash
     terraform apply
     ```
   - Then, we will need to create our kubectl manifest for the CA. For that, we will run the following commands:
     ```bash
     export CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
     export AWS_REGION=$(terraform output -raw aws_region)
     export EKS_CLUSTER_AUTOSCALER_IAM_ROLE_ARN=$(terraform output -raw eks_cluster_autoscaler_role_arn)

     helm repo add autoscaler https://kubernetes.github.io/autoscaler
     helm template cndro autoscaler/cluster-autoscaler \
        --namespace kube-system \
        --set "autoDiscovery.clusterName=$CLUSTER_NAME" \
        --set "awsRegion=$AWS_REGION" \
        --set "rbac.serviceAccount.name=cluster-autoscaler-sa" \
        --set "rbac.serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=$EKS_CLUSTER_AUTOSCALER_IAM_ROLE_ARN" > autoscaling/cluster-autoscaler.yml
     ```
   - After that, we will need to apply the manifest:
     ```bash
     kubectl apply -f autoscaling/cluster-autoscaler.yml
     ```
   - Finally, we will need to check if the CA is running and watch the logs:
     ```bash
     kubectl get deployment -n kube-system cndro-aws-cluster-autoscaler
     ```

5. **Test Cluster Autoscaler with HPA**
   - Add some load to our Sample application to trigger the HPA and CA. For that we will use and additional container to generate load.
     ```bash
     kubectl run -i --tty load-generator --image=busybox /bin/sh
     ```
     Inside the container, run the following command to generate load:
     ```bash
     while true; do wget -q -O- http://php-apache; done
     ```
   - You can watch the HPA scaling up the pods:
     ```bash
     kubectl get hpa -w
     ```
     You will see HPA scale the pods from 1 up to our configured maximum (10) until the CPU average is below our target (50%)
   - You should see the CA scaling up the nodes in the EKS cluster. You can check the logs of the CA pod to see the scaling events:
     ```bash
     kubectl logs -f -n kube-system deployment/cndro-aws-cluster-autoscaler
     ```
   - You can also check the EKS console to see the new nodes being added to the cluster or in the Kube Ops View dashboard.
   - To stop the load generator, you can press `Ctrl+C`. This will stop the load generation and allow the HPA to scale down the pods
   and CA to scale down the nodes. You should also get out of the load testing application by pressing `Ctrl+D` or typing `exit`.

6. **Migrate from CA to Karpenter**
   - Install Karpenter. For that, we will need to run the following commands:
     ```bash
     export CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
     export CLUSTER_ENDPOINT=$(terraform output -raw eks_cluster_endpoint)
     export KARPENTER_IAM_ROLE_ARN=$(terraform output -raw karpenter_role_arn)
     export KARPENTER_SERVICE_ACCOUNT_NAME=$(terraform output -raw karpenter_service_account_name)
     export KARPENTER_NAMESPACE=$(terraform output -raw karpenter_namespace)
     export KARPENTER_INTERUPTION_QUEUE=$(terraform output -raw karpenter_interuption_queue_name)
     export KARPENTER_VERSION="1.3.3"

     helm install karpenter oci://public.ecr.aws/karpenter/karpenter --version ${KARPENTER_VERSION} \
        --namespace ${KARPENTER_NAMESPACE} --create-namespace \
        --set serviceAccount.name=${KARPENTER_SERVICE_ACCOUNT_NAME} \
        --set serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn=${KARPENTER_IAM_ROLE_ARN} \
        --set settings.clusterName=${CLUSTER_NAME} \
        --set settings.clusterEndpoint=${CLUSTER_ENDPOINT} \
        --set settings.interruptionQueue=${KARPENTER_INTERUPTION_QUEUE} \
        --set settings.featureGates.spotToSpotConsolidation=true \
        --set controller.resources.requests.cpu=100m \
        --set controller.resources.requests.memory=128Mi \
        --set controller.resources.limits.cpu=500m \
        --set controller.resources.limits.memory=500Mi \
        --set replicas=1 \
        --wait
     ```
   - Remove Cluster Autoscaler from our EKS cluster. Uninstall CA by running the following command:
     ```bash
     kubectl delete -f autoscaling/cluster-autoscaler.yml
     ```
     Then, you can remove the IAM role created by terraform by opening `terraform.tfvars` and setting the following variable:
     ```hcl
     enable_eks_cluster_autoscaler = false
     ```
     and running terraform again:
     ```bash
     terraform apply
     ```
   - Create Karpenter NodePool
     ```bash
     kubectl apply -f autoscaling/karpenter.yml
     ```
   - Now you can start testing Karpenter autoscaling. You can use the same load generator as before to test Karpenter autoscaling.
   - You can see the Karpenter logs by running the following command:
     ```bash
     kubectl logs -f -n karpenter deployment/karpenter
     ```
   - You can also check the EKS console to see the new nodes being added to the cluster or in the Kube Ops View dashboard.
   - To stop the load generator, you can press `Ctrl+C`. This will stop the load generation and allow the HPA to scale down the pods
   and Karpenter to scale down the nodes. You should also get out of the load testing application by pressing `Ctrl+D` or typing `exit`.

7. **Cleanup**
   - To clean up the resources created during the workshop, you can run the following command:
     ```bash
     terraform destroy
     ```
   - You will need to manually remove the S3 bucket created to store terraform stack.

## External Resources
- [AWS EKS](https://aws.amazon.com/eks/)
- [Cluster Autoscaler](https://github.com/kubernetes/autoscaler/blob/master/cluster-autoscaler/cloudprovider/aws/README.md)
- [Karpenter](https://karpenter.sh/docs/)


# Terraform Code Documentation
<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 5.83.0 |
| <a name="requirement_http"></a> [http](#requirement\_http) | 3.4.5 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.83.1 |
| <a name="provider_http"></a> [http](#provider\_http) | 3.4.5 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.2.3 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_eks"></a> [eks](#module\_eks) | terraform-aws-modules/eks/aws | ~> 20.31 |
| <a name="module_karpenter"></a> [karpenter](#module\_karpenter) | terraform-aws-modules/eks/aws//modules/karpenter | n/a |
| <a name="module_vpc"></a> [vpc](#module\_vpc) | terraform-aws-modules/vpc/aws | 5.19.0 |

## Resources

| Name | Type |
|------|------|
| [aws_budgets_budget.cost](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/budgets_budget) | resource |
| [aws_iam_policy.eks_cluster_autoscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_policy) | resource |
| [aws_iam_role.eks_cluster_autoscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy_attachment.eks_cluster_autoscaler](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [null_resource.generate_kubeconfig](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [http_http.myip](https://registry.terraform.io/providers/hashicorp/http/3.4.5/docs/data-sources/http) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_availability_zones"></a> [availability\_zones](#input\_availability\_zones) | List of availability zones to use for the VPC | `list(string)` | n/a | yes |
| <a name="input_eks_cluster_name"></a> [eks\_cluster\_name](#input\_eks\_cluster\_name) | Name of the EKS cluster | `string` | `"cndro-eks"` | no |
| <a name="input_eks_cluster_version"></a> [eks\_cluster\_version](#input\_eks\_cluster\_version) | Version of the EKS cluster | `string` | `"1.31"` | no |
| <a name="input_email_address"></a> [email\_address](#input\_email\_address) | Please enter your valid email address<br/>Email address will be used to receive budget notifications | `string` | n/a | yes |
| <a name="input_enable_budget"></a> [enable\_budget](#input\_enable\_budget) | Enable budget notifications | `bool` | `true` | no |
| <a name="input_enable_eks_cluster_autoscaler"></a> [enable\_eks\_cluster\_autoscaler](#input\_enable\_eks\_cluster\_autoscaler) | Create EKS Cluster Autoscaler role and policy | `bool` | `true` | no |
| <a name="input_enable_karpenter"></a> [enable\_karpenter](#input\_enable\_karpenter) | Create Karpenter role and policy | `bool` | `false` | no |
| <a name="input_karpenter_namespace"></a> [karpenter\_namespace](#input\_karpenter\_namespace) | Karpenter namespace | `string` | `"karpenter"` | no |
| <a name="input_karpenter_service_account"></a> [karpenter\_service\_account](#input\_karpenter\_service\_account) | Karpenter service account | `string` | `"karpenter"` | no |
| <a name="input_karpenter_use_spot_instances"></a> [karpenter\_use\_spot\_instances](#input\_karpenter\_use\_spot\_instances) | Use spot instances in Karpenter | `bool` | `false` | no |
| <a name="input_public_subnets"></a> [public\_subnets](#input\_public\_subnets) | List of public subnets to create in the VPC | `list(string)` | n/a | yes |
| <a name="input_region"></a> [region](#input\_region) | AWS region to deploy resources in | `string` | `"eu-central-1"` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_aws_region"></a> [aws\_region](#output\_aws\_region) | AWS region where the resources are deployed |
| <a name="output_eks_cluster_autoscaler_role_arn"></a> [eks\_cluster\_autoscaler\_role\_arn](#output\_eks\_cluster\_autoscaler\_role\_arn) | EKS Cluster Autoscaler Role ARN |
| <a name="output_eks_cluster_endpoint"></a> [eks\_cluster\_endpoint](#output\_eks\_cluster\_endpoint) | EKS Endpoint for EKS control plane |
| <a name="output_eks_cluster_name"></a> [eks\_cluster\_name](#output\_eks\_cluster\_name) | EKS Cluster Name |
| <a name="output_eks_kubeconfig_command"></a> [eks\_kubeconfig\_command](#output\_eks\_kubeconfig\_command) | Command to configure kubectl to use the EKS cluster |
| <a name="output_karpenter_interuption_queue_name"></a> [karpenter\_interuption\_queue\_name](#output\_karpenter\_interuption\_queue\_name) | Karpenter Interruption Queue Name |
| <a name="output_karpenter_namespace"></a> [karpenter\_namespace](#output\_karpenter\_namespace) | Karpenter Namespace |
| <a name="output_karpenter_role_arn"></a> [karpenter\_role\_arn](#output\_karpenter\_role\_arn) | Karpenter Role ARN |
| <a name="output_karpenter_service_account_name"></a> [karpenter\_service\_account\_name](#output\_karpenter\_service\_account\_name) | Karpenter Service Account Name |
| <a name="output_my_ip_address"></a> [my\_ip\_address](#output\_my\_ip\_address) | My public IP address |
<!-- END_TF_DOCS -->
