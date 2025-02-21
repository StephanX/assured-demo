# assured-demo


Steps:

0) Contents of `environments/root` enumerate a new organizational unit within a root account and create a new root user for the OU.  That root user needs to manually reset the the AWS account password and create initial console access credentials, which get stored in `environments/secrets.source` (refer to `environments/secrets.source.example`).  Finally, accounts require a credit card in the billing section.  Account activation may require direct support from AWS to enable most services.

1) run terraform init from within the terraform/environments/<environment> directory.  This downloads the required additional binaries required by terraform.

2) run the ./bootstrap.sh within the environment.  This creates the initial terraform state bucket and robot service account user that will be used for the rest of the cluster stand up.

3) Copy the contents of terraform/skeleton/1-phase into terraform/environments/<environment>.  Run terraform apply.  Again with 2-phase, then 3-phase

Challenges:
- Initial installation of Consul + Vault is a challenge to automate.  I had to perform several manual tasks.  Once the Vault is established, it becomes the source of truth for every other meaningful secret storage, thus it needs to be set up correctly.  Having a functional ops kubernetes cluster helps this, but it becomes a chicken-and-egg problem.  In practice, once an ops cluster with vault is established, it is expected to rarely change outside of minor, tested version upgrades.  WARNING: do NOT include secret resources within the ops cluster that depends on the vault within the ops cluster.  If the vault becomes inaccessible, manual intervention would be required to use terraform on that cluster again.
- Initial creation of the new sub organizations and accounts requires browser interaction with the AWS consul to
  .a set the initial root account login and
  .b set the initial billing data for each organization
As of 24 hours later, these accounts still do not have access to most resources, like EC2
- Domain registration and propagation is also time consuming, between 15 and 60 minutes.  These need to be performed in advance of a time sensitive demonstration.
- Creation of certain resources require upwards of 20 minutes, especially the EKS masters, EKS worker groups, and any AWS managed databases.
- ArgoCD also requires manual creation of certain authentication methods via the web gui.
- externalDNS domain names and cert-manager/letsencrypt certs are also less than time efficient