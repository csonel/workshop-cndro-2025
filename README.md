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
     kubectl apply -k kube-ops-view-deployment
     
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
   - Install Karpenter
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
     kubectl logs -f -n kube-system deployment/karpenter-controller
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

