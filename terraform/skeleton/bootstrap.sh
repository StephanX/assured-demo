#!/bin/bash
set -e

if [ -f secrets.source ] ; then
  source secrets.source
  else echo "ERROR: secrets.source NOT configured, aborting..." && exit 1
fi

for file in \
  terraform-s3-backend-resources.tf \
  variables.tf \
  versions.tf
do
  ln -sf ../../skeleton/${file} .
done

TF_FIXTURES=$(for i in $(ls fixtures* 2> /dev/null | grep -v "fixtures.sensitive.s3.tf_vars" 2> /dev/null);
do
    echo -n "-var-file=${i} ";
done);


terraform init

terraform apply ${TF_FIXTURES} -auto-approve -target=aws_s3_bucket.terraform-state

echo "waiting until s3 bucket is available."
sleep 2
TFSTATE_FULL_NAME=$(grep company fixtures.tfvars | awk -F '"' '{ print $2 }')-$(grep root_name fixtures.tfvars | awk -F '"' '{ print $2 }'
)

TFSTATE_BUCKET_NAME="${TFSTATE_FULL_NAME}-terraform-state"
BUCKET_READY=1
while [[ ${BUCKET_READY} != 0 ]] ; do
  printf "."
  sleep 1
  echo aws s3api head-bucket --bucket ${TFSTATE_BUCKET_NAME}
  aws s3api head-bucket --bucket ${TFSTATE_BUCKET_NAME} 2>&1>>/dev/null
  BUCKET_READY=$? # checks exit code of the previous action
done
echo ""

terraform init ${TF_FIXTURES} -migrate-state -force-copy

# generate root domain Nameserver records
terraform apply ${TF_FIXTURES} -auto-approve -target=aws_route53_zone.root

echo "WARNING: provisioning additional resources will require manually adding a credit card to the billing portal!  Ref: https://aws.amazon.com/registration-confirmation/"

read -p "Pausing for discussion, press enter to continue, anything else to abort..."

for file in \
  route53.tf \
  context.tf \
  kubernetes-vpc-cluster-nodegroups.tf \
  kubernetes-access.tf
do
  ln -sf ../../skeleton/${file} .
done

terraform init

terraform apply ${TF_FIXTURES} -auto-approve

aws eks update-kubeconfig --name ops-cluster

echo "UPDATE ROOT DOMAIN DNS NAME!"