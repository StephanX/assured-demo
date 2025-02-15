#!/bin/bash


if [ -f ../secrets.source ] ; then
  source ../secrets.source
  else echo "ERROR: secrets.source NOT configured, aborting..." && exit 1
fi

TF_FIXTURES=$(for i in $(ls fixtures* 2> /dev/null | grep -v "fixtures.sensitive.s3.tf_vars" 2> /dev/null);
  do
      echo -n "-var-file=${i} ";
  done)

cat > destroy-backend.tf << EOF
terraform {
  backend "local" {}
}

EOF

rm -f terraform-s3-backend-config.tf

# comment out s3 lifecycle preventing bucket deletion by terraform
sed '/lifecycle/,+3d' terraform-s3-backend-resources.tf >> destroy-backend.tf

mv terraform-s3-backend-resources.tf terraform-s3-backend-resources.tf.bak



# # terraform apply ${TF_FIXTURES} -auto-approve

# terraform init ${TF_FIXTURES} -reconfigure -force-copy

# terraform destroy ${TF_FIXTURES} -auto-approve

# remove state files and temporary backend file
rm -rf terraform.tfstate* destroy-backend.tf .terraform/terraform.tfstate*

TFSTATE_FULL_NAME=$(grep company fixtures.tfvars | awk -F '"' '{ print $2 }')-$(grep root-name fixtures.tfvars | awk -F '"' '{ print $2 }'
)

TFSTATE_BUCKET_NAME="${TFSTATE_FULL_NAME}-terraform-state"

TFSTATE_REGION=$(grep region fixtures.tfvars | awk -F '"' '{ print $2 }'
)

# terraform still doesn't actually delete the bucket, we need a manual clean up.  Versioned buckets aren't trivial to delete from the CLI

# delete versions
aws s3api delete-objects --bucket ${TFSTATE_BUCKET_NAME} \
--delete "$(aws s3api list-object-versions --bucket ${TFSTATE_BUCKET_NAME} --query='{Objects: Versions[].{Key:Key,VersionId:VersionId}}')"

# delete version markers
aws s3api delete-objects --bucket ${TFSTATE_BUCKET_NAME} \
--delete "$(aws s3api list-object-versions --bucket ${TFSTATE_BUCKET_NAME} --query='{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}')"
aws s3api delete-bucket --bucket ${TFSTATE_BUCKET_NAME}
aws s3api list-buckets | grep Buckets

# clean up dynamodb table
TFSTATE_DYNAMODB_NAME="${TFSTATE_FULL_NAME}-terraform-locks"
aws dynamodb delete-table --region=${TFSTATE_REGION} --table-name ${TFSTATE_DYNAMODB_NAME}

mv terraform-s3-backend-resources.tf.bak terraform-s3-backend-resources.tf


RED='\033[0;31m'
NC='\033[0m' # No Color
ITALICS='\e[3m'
NOITALICS='\e[0m'
printf "Sark: ${RED}${ITALICS}End of Line.${NC}${NOITALICS}\n"




