# assured-demo


Steps:

0) Contents of `environments/root` enumerate a new organizational unit within a root account and create a new root user for the OU.  That root user needs to manually reset the the AWS account password and create initial console access credentials, which get stored in `environments/secrets.source` (refer to `environments/secrets.source.example`

1) run terraform init from within the bootstrap directory.  This creates the initial terraform state bucket and robot service account user that will be used for the rest of the cluster stand up.

