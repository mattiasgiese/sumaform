 # AWS-specific configuration

## Overview

Base Module will create:
 - a VPC
 - two subnets
   - one private, that can only access other hosts in the VPC
   - one public, that can also access the Internet and accepts connections from an IP whitelist
 - security groups, routing tables, Internet gateways as appropriate
 - one `mirror` host should be created in the public network to work as a bastion host

This architecture is loosely inspired from [Segment's AWS Stack](https://segment.com/blog/the-segment-aws-stack/).

## Prerequisites

You will need:
 - an AWS account, specifically an Access Key ID and a Secret Access Key
 - [an SSH key pair](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-key-pairs.html#having-ec2-create-your-key-pair) valid for that account
 - the name of the region you want to use.

## Select AWS backend to be used

Create a symbolic link to the `aws` backend module directory inside the `modules` directory: `ln -sfn ../backend_modules/aws modules/backend`

## AWS backend specific variables

Most modules have configuration settings specific to the AWS backend, those are set via the `provider_settings` map variable. They are all described below.

### Base Module
Available provider settings for the base module:

| Variable name      | Type   | Default value | Description                                                              |
|--------------------|--------|---------------|--------------------------------------------------------------------------|
| region             | string | `null`        | AWS region where infrastructure will be created                          |
| availability_zone  | string | `null`        | AWS availability zone inside region                                      |
| ssh_allowed_ips    | array  | `[]`          | Array of IP's to white list for ssh connection                           |
| key_name           | string | `null`        | ssh key name in AWS                                                      |
| key_file           | string | `null`        | ssh key file                                                             |
| ssh_user           | string | `ec2-user`    | ssh user                                                                 |
| bastion_host       | string | `null`        | bastian host use to connect machines in private network                  |
| additional_network | string | `null`        | A network mask for PXE tests                                             |

An example follows:
```hcl-terraform
...
provider_settings = {
    region            = "eu-west-3"
    availability_zone = "eu-west-3a"
    ssh_allowed_ips   = ["1.2.3.4"]
    key_name = "my-aws-key"
    key_file = "/path/to/key.pem"
}
...
```

### Host modules

Following settings apply to all modules that create one or more hosts of the same kind, such as `suse_manager`, `suse_manager_proxy`, `client`, `grafana`, `minion`, `mirror`, `sshminion`, `pxe_boot` and `virthost`:

| Variable name   | Type     | Default value                                                    | Description                                                         |
|-----------------|----------|------------------------------------------------------------------|---------------------------------------------------------------------|
| key_name        | string   | [from base Module](base-module)                                  | ssh key name in AWS                                                 |
| key_file        | string   | [from base Module](base-module)                                  | ssh key file                                                        |
| ssh_user        | string   | [from base Module](base-module)                                  | ssh user                                                            |
| bastion_host    | string   | [from base Module](base-module)                                  | bastian host use to connect machines in private network             |
| public_instance | boolean  | `false`                                                          | boolean to set host to private or public network                    |
| volume_size     | number   | `50`                                                             | main volume size in GB                                              |
| instance_type   | string   | `t2.micro`([apart from specific roles](Default-values-by-role))  | [AWS instance type](https://aws.amazon.com/pt/ec2/instance-types/)  |

An example follows:
```hcl
...
  provider_settings = {
    public_instance = true
    instance_type   = "t2.small"
  }
...
```

`server`, `proxy` and `mirror` modules have configuration settings specific for extra data volumes, those are set via the `volume_provider_settings` map variable. They are described below.

 * `volume_snapshot_id = <String>` data volume snapshot id to be used as base for the new disk (default value `null`)
 * `type = <String>` Disk type that should be used (default value `sc1`). One of: "standard", "gp2", "io1", "sc1" or "st1".

 An example follows:
 ``` hcl
volume_provider_settings = {
  volume_snapshot_id = "my-data-snapshot"
}
```

#### Default provider settings by role

Some roles such as `server` or `mirror` have specific defaults that override those in the table above. Those are:

| Role         | Default values                |
|--------------|-------------------------------|
| server       | `{instance_type="t2.medium"}` |
| mirror       | `{instance_type="t2.micro"}`  |
| controller   | `{instance_type="t2.medium"}` |
| grafana      | `{instance_type="t2.medium"}` |
| virthost     | `{instance_type="t2.small"}`  |
| pts_minion   | `{instance_type="t2.medium"}` |


## mirror

In addition to acting as a bastion host for all other instances, the `mirror` host serves all repos and packages used by other instances. 
It works similarly to the one for the libvirt backend, allowing instances in the private subnet to be completely disconnected from the Internet. 
The `mirror` host's data volume can be created from a pre-populated snapshot, which allows it to be operational without lengthy channel synchronization.

#### Set up mirror machine

When creating mirror machine two options exists:

* Creating using a data disk snapshot:
```hcl
data "aws_ebs_snapshot" "data_disk_snapshot" {
  most_recent = true

  filter {
    name   = "tag:Name"
    values = ["mirror-data-volume-snapshot"]
  }
}

module "mirror" {
  source = "./modules/mirror"

  base_configuration = module.base.configuration
  provider_settings = {
    public_instance = true
  }
  volume_provider_settings = {
    volume_snapshot_id = data.aws_ebs_snapshot.data_disk_snapshot.id
  }
}
``` 

* Creating with empty data disk (if no snapshot is available):

```hcl
module "mirror" {
  source = "./modules/mirror"

  base_configuration = module.base.configuration

  provider_settings = {
    public_instance = true
  }
}
```

More information in [mirror setup](main.tf.aws-create-mirror-snapshot.example)

#### Creating data disk snapshot

Requirements:
* Mirror machine in AWS, with the data disk (could be base on pré-existing snapshot, as mentioned before) 
* Access to a full sync mirror (could be local) from where we will sync all needed packages 

Steps: 
1. Re-sync all content
    1. `scp <YOUR_AWS_KEY> root@<MIRROR_HOST>://root/key.pem`
    2. `ssh root@<MIRROR_HOST>`
    3. `zypper in rsync`
    4. `rsync -av0 --delete -e 'ssh -i key.pem' /srv/mirror/ ec2-user@<PUBLIC DNS NAME>://srv/mirror/`

2. Create a disk snapshot
    ```hcl
    data "aws_ebs_volume" "data_disk_id" {
      most_recent = true
    
      filter {
        name   = "tag:Name"
        values = ["${module.base.configuration["name_prefix"]}mirror-data-volume"]
      }
    }
    
    resource "aws_ebs_snapshot" "mirror_data_snapshot" {
      volume_id = data.aws_ebs_volume.data_disk_id.id
    
      tags = {
        Name = "mirror-data-volume-snapshot"
      }
    }
    ```
3. In case you want to delete the mirror instance but keep the snapshot
    1. remove snapshot module from terraform state: `terraform state rm aws_ebs_snapshot.mirror_data_snapshot`
    2. If you now run `terraform destroy` the snapshot will be preserved. 
    However, if one run `terraform apply` again a new snapshot will be created.

#### Force re-creation of existing data disk snapshot

If one keeps the snapshot create resource in is root module, the snapshot will not be re-created unless one forces it by marking the resource as taint.
To remove the older snapshot and create a new one run: `terraform taint aws_ebs_snapshot.mirror_data_snapshot`

## Accessing instances

`mirror` is accessible through SSH at the public name noted in outputs.

```
$ terraform apply
...
Apply complete! Resources: 0 added, 0 changed, 0 destroyed.

Outputs:

mirror_public_name = ec2-XXX-XXX-XXX-XXX.compute-1.amazonaws.com

$ ssh -i key.pem root@ec2-XXX-XXX-XXX-XXX.compute-1.amazonaws.com
ip-YYY-YYY-YYY-YYY:~ #
```

Other hosts are accessible via SSH from the `mirror` itself.

This project provides a utility script, `configure_aws_tunnels.rb`, which will add `Host` definitions in your SSH config file so that you don't have to input tunneling flags manually.

```
$ terraform apply
...
$ ./configure_aws_tunnels.rb
$ ssh server
ip-YYY-YYY-YYY-YYY:~ #
```
