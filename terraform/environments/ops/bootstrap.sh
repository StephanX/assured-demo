#!/bin/bash
set -e

if [ -f ../secrets.source ] ; then
  source ../secrets.source
  else echo "ERROR: secrets.source NOT configured, aborting..." && exit 1
fi

TF_FIXTURES=$(for i in $(ls fixtures* 2> /dev/null | grep -v "fixtures.sensitive.s3.tf_vars" 2> /dev/null);
do
    echo -n "-var-file=${i} ";
done);

terraform init ${TF_FIXTURES}

terraform apply ${TF_FIXTURES} -auto-approve -target=aws_s3_bucket.terraform-state

echo "waiting until s3 bucket is available."
sleep 2
TFSTATE_ROOT_NAME=$(grep root-name fixtures.tfvars | awk -F '"' '{ print $2 }'
)
TFSTATE_BUCKET_NAME="${TFSTATE_ROOT_NAME}-terraform-state"
BUCKET_READY=254
while [[ ${BUCKET_READY} != 0 ]] ; do
  printf "."
  sleep 1
  aws s3api head-bucket --bucket ${TFSTATE_BUCKET_NAME} 2>&1>>/dev/null
  BUCKET_READY=$? # checks exit code of the previous action
done
echo ""

terraform apply ${TF_FIXTURES} -auto-approve

terraform init ${TF_FIXTURES} -migrate-state -force-copy

