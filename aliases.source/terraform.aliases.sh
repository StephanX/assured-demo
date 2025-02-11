tfr() {
  TF_AUTO_APPROVE='';
  TF_FIXTURES='';
  TF_FIXTURES=$(for i in $(ls fixtures* 2>/dev/null| grep -v "fixtures.sensitive.s3.tf_vars" 2>/dev/null) ; do echo -n "-var-file=${i} " ; done)
  [[ ${1} == "-y" ]] && TF_AUTO_APPROVE='-auto-approve' && shift
  terraform apply ${TF_AUTO_APPROVE} ${TF_FIXTURES} ${@}
  unset TF_AUTO_APPROVE
}

tfd() {
  TF_AUTO_APPROVE='';
  TF_FIXTURES='';
  TF_FIXTURES=$(for i in $(ls fixtures* 2>/dev/null| grep -v "fixtures.sensitive.s3.tf_vars" 2>/dev/null) ; do echo -n "-var-file=${i} " ; done)
  [[ ${1} == "-y" ]] && TF_AUTO_APPROVE='-auto-approve';
  terraform destroy ${TF_AUTO_APPROVE} ${TF_FIXTURES} ${@}
  unset TF_AUTO_APPROVE
}

tfi() {
  TF_FIXTURES='';
  TF_FIXTURES=$(for i in $(ls fixtures* 2>/dev/null| grep -v fixtures.sensitive.s3.tf_vars 2>/dev/null) ; do echo -n "-var-file=${i} " ; done);
  terraform import ${TF_FIXTURES} ${@}
}

tfinit() {
  [ -f fixtures.sensitive.s3.tf_vars ] && TF_S3_STATE="-backend-config=fixtures.sensitive.s3.tf_vars"
  terraform init ${TF_FIXTURES} ${TF_S3_STATE} ${@}
}

tfp() {
  TF_FIXTURES='';
  TF_FIXTURES=$(for i in $(ls fixtures* 2>/dev/null| grep -v "fixtures.sensitive.s3.tf_vars" 2>/dev/null) ; do echo -n "-var-file=${i} " ; done);
  terraform plan ${TF_FIXTURES} ${@}
}

tfrefresh() {
  TF_FIXTURES='';
  TF_FIXTURES=$(for i in $(ls fixtures* 2>/dev/null| grep -v "fixtures.sensitive.s3.tf_vars" 2>/dev/null); do echo -n "-var-file=${i} " ; done);
  terraform refresh ${TF_FIXTURES}
}

tfo() {
  terraform output ${@}
}
