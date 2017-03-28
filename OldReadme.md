# WebRTC Scripts

The scripts in this directory manage the lifecycle of the WebRTC infrastructure. They are also used by the
TeamCity build server to deploy new versions of WebRTC services to their respective nodes.

## Introduction

The WebRTC infrastructure can be described in terms of *nodes*, *roles* and
*services*.

- A **node** is physical EC2 instance on AWS. Each instance will fulfill one role, though there may be more than one
node for each role.

- A **role** is a logical grouping of functionality. Each role will be implemented by either one of our Java services
or by another mechanism (ie: an Apache server for simple HTTP).

- A **service** is an implementation of one or more roles. These services are available in the main repository.

The following sections will describe these components in more detail.

### Requirements

Users who do not have experience with AWS or dev-ops patterns will have to download some additional tools to run these
scripts. This section will only briefly cover these tools. Their use will be described in in greater detail in the
*Tools* section of this document.

#### PowerShell 4.0+ ####

As the team members are developing primarily on Windows, PowerShell will be the driver for these
scripts.

A recent version of PowerShell is required. If an older version is installed, update your copy by downloading the latest
version of the Windows Management Framework.

[[Download]](https://www.microsoft.com/en-us/download/details.aspx?id=50395)

#### AWS Command Line Interface ####

The scripts require that the AWS command line interface is installed and available on the current user's `PATH`. In
addition, several environment variables must be set:

- **AWS_DEFAULT_REGION**: The AWS region where our infrastructure resides, `us-west-2`.
- **AWS_ACCESS_KEY_ID**: The id of the AWS access key that will be used to manage AWS resources. This should be the id
of the provisioning user, not your personal access key id.
- **AWS_SECRET_ACCESS_KEY**: The AWS secret key that is used to verify the identity of the provisioning user. Again,
this should not be your personal secret key.

[[Download]](https://aws.amazon.com/cli/)

#### Packer 0.10.0+ ####

Packer is a command line utility that generates virtual machine images from JSON configuration files. It is used to
generate AMIs to provision our EC2 instances. A recent version of Packer must be installed and available on the current
user's `PATH`.

[[Download]](https://packer.io/downloads.html)

#### Terraform 0.7.2+ ####

Terraform is a command line utility that is used to spin up and destroy infrastructure. It is used to manage the
lifecycle of various AWS resources. A recent version of Terraform must be installed and available on the current user's
`PATH`.

[[Download]](https://terraform.io/downloads.html)

#### Python 3.3+ ####

Python is used to deploy JAR files and other build artifacts. You will need to install Python 3 as well as the Paramiko
module. The Paramiko module is available through pip. You can install it with the following command:

```
pip install paramiko
```

If you do not have pip installed, re-install Python 3 using the installer below and select the "Advanced Setup" option.
There is an option in this dialog to install pip.

The choice of python for this task was to accommodate scenarios in which individual developers may want to push build
artifacts to a specific node. Python is cross-platform, which means these scripts can also be used by the TeamCity
server for its deployment tasks.

[[Download]](https://www.python.org/downloads/windows/)

### Roles and Role Groups

The functionality of the WebRTC component is split across various roles. There are five `core` roles:

- The **media** role is a STUN/TURN server and handles all session management and advanced session configurations, such
as multiplexing.
- The **signaling** role is a socket.io server and relays messages between nodes.
- The **recording** role is a headless peer that joins conferences to record what the user sees.
- The **auth** role is a web server that authorizes requests to use the media server.
- The **demo** role is another web server that hosts the sample JavaScript application.

Each of these core roles is associated with a stage/environment. There will be at least one for each different
environment.

There are also `meta` roles, which are not part of the WebRTC component but are related to it. Meta roles are not
associated with an environment. Currently, there is only one role in this group:

- The **teamcity** role is a CI server that performs continuous deployment.

We refer to `core` and `meta` as role groups. When executing these scripts, you will often be asked to specify which
group of roles you would like to manage.

Example commands:
```
provision core auth,media,signaling production
provision meta teamcity
```

## Tools

This section provides an overview of the technologies used in these scripts. This is a "quick start" for developers who
may be unfamiliar with the tools. You may safely skip over this section if you have use these tools before. For more
detailed information, please refer to the documentation of the tool in question.

### PowerShell

PowerShell is modern Windows' scripting language. All PowerShell scripts are written without using aliases. While this
may seem unnecessarily verbose, use of aliases can confusing, as seen [here](https://github.com/PowerShell/PowerShell/pull/1901).

The core PowerShell scripts are available in the root `scripts` directory. These scripts make use of several re-usable
modules, which are located in the `scripts/psm` folder.

### Packer

Packer is the first part of the build pipeline. In `scripts/packer/main`, observe that there are several JSON files.
Each file describes how to build the AMI for a single role.

For an example of how this works, examine the `builders` configuration block:

```
"builders": [{
  "type": "amazon-ebs",
  "region": "{{ user `aws_region` }}",
  ...
```

The `type` property describes the type of `builder`. We are using the `amazon-ebs` builder, which builds an AMI backed
by an elastic block store. You can read more about the syntax for this builder [here](https://www.packer.io/docs/builders/amazon.html).

Also, notice the odd curly brace syntax, which indicates a user variable. These are passed into packer via the command
line. The actual packer command line call in the provisioning script looks like:

```
packer build media.json  -var 'aws_source_ami=ami-f3befc93'
```

The last thing to examine is the `provisioners` block, which describes three *provisioners*:

```
"provisioners": [{
  "type": "shell",
  "script": "../shared/ansible-bootstrap.sh",
  ...
}, {
  "type": "shell",
  "script": "../shared/ansible-galaxy.sh",
  ...
}, {
  "type": "ansible-local",
  ...
}] 
```

Each provisioner performs some action on the AMI. The provisioners are, by design, minimal. Their only purpose is to
install and run Ansible, which is a configuration management tool.

The first provisioner runs the shell script `ansible-bootstrap.sh`. The only thing it does is update apt and install
Ansible.

The second provisioner runs another shell script, `ansible-galaxy.sh`. This script runs ansible-galaxy, which is a
command line utility for downloading re-usable sets of Ansible functionality.

The third provisioner is not a script. It uploads an Ansible configuration to the remote host and executes Ansible on
the remote host over SSH. The next section will explain what Ansible is in more detail.

Each packer run is set to output verbose logs to the `scripts/packer/[RoleGroup]/logs` directory. The log output that is
written to the file will be more detailed than what is displayed in the console, so check there first if there are any
problems during the execution of a script.

### Ansible

Ansible is a configuration management tool. Through Packer, we use this tool to define what applications should be
installed on a given host and define any other parameters that may need to be configured. Packer will create a temporary
EC2 instance, upload our Ansible files, and execute them on the remote host. Afterwards, Packer will shut down the EC2
instance and use it to create an AMI.

Ansible organizes its directives into YAML files that are referred to as `playbooks`. Theses playbooks are located in
the `scripts/ansible/[roleGroup]/` directories. The project currently only has two playbooks, one for each role group.
These are in the `site.yml` file for each role group.

Viewing the core role group's `site.yml` playbook, you will see a number of elements, each of which is referred to as a 
`play`. It will look something like this:

```
- name: apply common configuration to all nodes
  hosts: all
  vars_files:
    - vars/secret.yml
  roles:
    - ansiblebit.launchpad-ppa-webupd8
    - ansiblebit.oracle-java
    ...
```

The first thing to understand about this `play` is that the `name` is arbitrary. It only affects what is shown in the
console. The second thing to understand is that it applies to all hosts, as you may have guessed by the
`hosts: all` attribute. The set of all hosts is known as an `inventory`. Normally, we would pass Ansible an
`inventory file`, that would look something like this:

```
[media]
media1.webrtc.com
media2.webrtc.com

[signaling]
signaling.webrtc.com
```

In our case, this is unnecessary, as Packer will generate the necessary inventory file for us.  We are only using
Ansible to create AMIs, so we do not have to worry about the hostnames at this stage. Going back to the `site.yml` file
above, notice that there are several items listed under `roles`.

As touched on in the Packer section above, `roles` are re-usable Ansible configurations. Most of these roles are
downloaded using `ansible-galaxy`. The rest are defined in the `roles` directory. Most roles have a set of variables
associated with them that determine how they should be set up. For example, an Apache role would have a variable like
`http_port`, which would allow you to set the port to listen on.

Variables can be set in a number of ways but for our purposes there are three main places where we set these:

1. The `group_vars` directory defines variables for a specific host group. For example, the `auth` group_vars file 
defines variables that will be used whenever `hosts: auth` is specified in a play.
2. Variables included in `vars_files`. If you notice in the site.yml file above, we include a secrets.yml file. These
file name is arbitrary - we could include as many files as we want. We include the secrets separately in this way so
that we can encrypt them.
3. The core roles will have a play that looks like `- include_vars: "vars/{{ environment }}.yml"`. This is to include
the environment-specific variables for that role. These variables are defined under `roles/[role]/vars/[environment].yml`.

When executing an Ansible playbook, the log output will be under the same directory as the Packer logs. Read the output
carefully to check for the cause of errors.

### Terraform

*todo, see: terraform.io in the mean time.*

## Scripts

This section will go through the available scripts in detail and describe their usage. Before you can execute any of
them, you will have to tweak one or more PowerShell settings.

**Modifying Set-ExecutionPolicy**  
By default, PowerShell does not allow you to execute scripts that are not signed. For now, these scripts are not signed,
so you must bypass this policy by typing the following into a PowerShell command line interface:

```
Set-ExecutionPolicy RemoteSigned
```

More info: https://technet.microsoft.com/en-us/library/ee176961.aspx

**Running Scripts From The Current Directory**  
By default, PowerShell does not look in the current directory for scripts. You will have to run them in a manner similar
to how you would on a Unix system, which a current directory prefix, ie:

```
./encrypt.ps1
```

If you would like to run the scripts with a more terse syntax, you can add "." to your PATH environment variable. This
allows you to run scripts like:

```
encrypt
```

### Encryption (encrypt.ps1)

The encryption script encrypts secret files so that they can be safely committed to the repository. This solution is 
similar in goal to git-crypt/ansible-vault, which are unfortunately not available on Windows machines.

The list of files to encrypt is stored in scripts/secrets.txt. Each line in this document is the path to a file that
should be encrypted. A git commit hook will forbid you from committing if the files in secrets.txt have not been
encrypted. This prevents you from accidentally committing files that should not be in the repository.

The encryption is performed using AES with a 256 bit key. The key is generated from a passphrase using PBKDF2. You will
only have to enter this encryption key once. Its value will be encrypted and cached locally in the WEBRTC_AES_256
environment variable.

#### Usage Examples

Simple encryption:

```
encrypt
```

### Decryption (decrypt.ps1)

Opposite of the encryption script, the decryption script decrypts secret files that have been previous committed to the
repository. 

The list of files to decrypt is stored in scripts/secrets.txt. Each line in this document is the path to a file that
that should be decrypted. The actual file in the repository will have the suffix ".encrypted".

Again, the encryption is performed using AES with a 256 bit key based off of a passphrase. If you have previously
encrypted or decrypted files in the repository, the key will be cached in the **WEBRTC_AES256_KEY** environment
variable. This key should be the same as the one used to encrypt.

#### Usage Examples

Simple decryption:
```
decrypt
```

### Provisioning (provision.ps1)

The `provision` cmdlet creates AMIs based on a base Ubuntu AMI. For `meta` roles, the AMIs are environment agnostic.
For `core` roles, these are environment dependent. This means that each `core` role AMI is associated with a particular
environment.

The first act of the provisioning script is to return the most recent AMI for Ubuntu 14.04. Do not switch to Xenial and
assume everything will work. There are several issues that need to be corrected in the Ansible playbooks first, most
notably that the init.d scripts will not run.

Once the Base Ubuntu AMI is retrieved, the provisioning script executes packer for the selected roles. As each AMI is
completed, the new AMI ID will be copied over to the Terraform configuration file. For example, if we create an AMI for
signaling in the development environment, the script will copy the new AMI ID to the file:
`scripts/terraform/core/main-development/variables_signaling_override.tf`

The `override` portion of the filename instructs Terraform to apply the variables last. It is generally used for
machine-generated files, such as this.

#### Usage Examples

Build all AMIs for a role group:
```
provision meta
provision core development
```

Build some AMIs for a role group:
```
provision meta teamcity
provision core development signaling,media
```

### Applying Infrastructure (apply.ps1)

The `apply` cmdlet creates infrastructure for a given role group and environment. The configuration is defined in the
`scripts/terraform` directory. The `meta` role group has only one configuration, in `terraform/meta/main`. The `core` 
role group has one configuration for each environment, in `terraform/core/main-[environment]`.

This cmdlet is a lightweight wrapper around `terraform apply`.

#### Usage Examples

Create all infrastructure for a role group:
```
apply meta
apply core development
```

### Destroying Infrastructure (destroy.ps1)

The `apply` cmdlet destroys infrastructure for a given role group and environment. The configuration is defined in the
`scripts/terraform` directory. The `meta` role group has only one configuration, in `terraform/meta/main`. The `core` 
role group has one configuration for each environment, in `terraform/core/main-[environment]`.

This cmdlet is a lightweight wrapper around `terraform destroy`. Only infrastructure created by Terraform will be
destroyed.

#### Usage Examples

Destroy all infrastructure for a role group:
```
destroy meta
destroy core development
```

## AWS Information

### DNS and Name Servers

Terraform does not currently have the ability to change the name servers for a registered domain name; this must be done
through the AWS web console or command line interface. Because of this limitation, you must perform a few extra steps.

*Note, this may change. We may modify Terraform to take a set of nameservers instead, which alleviates this problem.*

#### Create a Re-usable Delegation Set

A delegation set is a collection of four name servers that AWS assigns to each Route53 hosted zone(collection of DNS
records). By default, when you create a hosted zone, you are assigned four new name servers. Creating a re-usable
delegation set allows you to instead specify an existing set of four servers.

There is no GUI for this, so you must perform this action through the command line interface:
```
aws route53 create-reusable-delegation-set --caller-reference xxxxxxxx
```

The caller reference can be anything unique and is simply a parameter to avoid executing the same operation twice. After
running this command, you should receive a block of data with an id parameter that looks something like 
`/delegationsets/NC26K6R8TY8VR` and an array of name servers. Keep track of both of these.

#### Update Domain Name Servers

Now that you have a set of re-usable name servers, you must update the name servers on your domain. If your domain is
hosted on AWS, you can update them through the Route 53 GUI. Otherwise, you must update them through whatever means the
registrar provides.

#### Delete the Default Hosted Zone


#### Update Terraform With New Delegation Set ID


### IAM Policies

There should be at least two IAM users and policies configured for this. 

**Provisioning IAM Policy:**
The first user should be the *terraform* or *provisioning* user. This is the identity under which the provisioning
scripts will execute. This user should have a policy with **at minimum** the following permissions:

```
{
    "Version": "",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:AcceptVpcPeeringConnection",
                "ec2:AttachInternetGateway",
                "ec2:AttachVolume",
                "ec2:AuthorizeSecurityGroupEgress",
                "ec2:AuthorizeSecurityGroupIngress",
                "ec2:CopyImage",
                "ec2:CreateImage",
                "ec2:CreateInternetGateway",
                "ec2:CreateKeyPair",
                "ec2:CreateNetworkAclEntry",
                "ec2:CreateRoute",
                "ec2:CreateSecurityGroup",
                "ec2:CreateSnapshot",
                "ec2:CreateSubnet",
                "ec2:CreateTags",
                "ec2:CreateVpc",
                "ec2:CreateVpcPeeringConnection",
                "ec2:DeleteInternetGateway",
                "ec2:DeleteKeyPair",
                "ec2:DeleteNetworkAclEntry",
                "ec2:DeleteRoute",
                "ec2:DeleteSecurityGroup",
                "ec2:DeleteSnapshot",
                "ec2:DeleteSubnet",
                "ec2:DeleteVolume",
                "ec2:DeleteVpc",
                "ec2:DeleteVpcPeeringConnection",
                "ec2:DescribeImages",
                "ec2:DescribeInstanceAttribute",
                "ec2:DescribeInstances",
                "ec2:DescribeInternetGateways",
                "ec2:DescribeKeyPairs",
                "ec2:DescribeNetworkAcls",
                "ec2:DescribeRouteTables",
                "ec2:DescribeSecurityGroups",
                "ec2:DescribeSnapshots",
                "ec2:DescribeSubnets",
                "ec2:DescribeVolumes",
                "ec2:DescribeVpcs",
                "ec2:DescribeVpcAttribute",
                "ec2:DescribeVpcClassicLink",
                "ec2:DescribeVpcPeeringConnections",
                "ec2:DetachInternetGateway",
                "ec2:DetachVolume",
                "ec2:ImportKeyPair",
                "ec2:ModifyImageAttribute",
                "ec2:ModifyInstanceAttribute",
                "ec2:ModifyVpcAttribute",
                "ec2:ModifyVpcPeeringConnectionOptions",
                "ec2:RegisterImage",
                "ec2:RebootInstances",
                "ec2:RevokeSecurityGroupEgress",
                "ec2:RevokeSecurityGroupIngress",
                "ec2:RunInstances",
                "ec2:StopInstances",
                "ec2:TerminateInstances",
                "iam:GetUser",
                "route53:ChangeResourceRecordSets",
                "route53:ChangeTagsForResource",
                "route53:CreateHostedZone",
                "route53:DeleteHostedZone",
                "route53:GetChange",
                "route53:GetHostedZone",
                "route53:ListResourceRecordSets",
                "route53:ListTagsForResource",
                "route53:UpdateHostedZoneComment"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:DeleteObject",
                "s3:ListBucket",
                "s3:GetObject",
                "s3:PutObject"
            ],
            "Resource": [
                "arn:aws:s3:::webrtc-webrtc",
                "arn:aws:s3:::webrtc-webrtc/*"
            ]
        }
    ]
}
```

**TeamCity IAM Policy**

The other IAM policy that should be defined will be for the teamcity server. This is a minimal policy that allows
backing up and retrieving configuration data from an S3 bucket. It should be the following:

```
{
    "Version": "",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:DescribeInstances",
                "ec2:RebootInstances"
            ]
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": "s3:ListAllMyBuckets",
            "Resource": "arn:aws:s3:::*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:*"
            ],
            "Resource": [
                "arn:aws:s3:::webrtc-webrtc",
                "arn:aws:s3:::webrtc-webrtc/*"
            ]
        }
    ]
}
```

## Troubleshooting
DevOps is notoriously finicky. There are a lot of things that can go wrong during this process and it can be difficult 
to find help online. When encountering any difficulties, check the logs first, as they are the best set of information.
