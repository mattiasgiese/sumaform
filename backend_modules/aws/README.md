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

~~SUSE employees using openbare already have AMI images uploaded and data snapshots for the us-east-1 region; others have to follow instructions in [HOW_TO_UPLOAD.md](modules/aws/images/HOW_TO_UPLOAD.md).~~

## Select AWS backend to be used

Create a symbolic link to the `aws` backend module directory inside the `modules` directory: `ln -sfn ../backend_modules/aws modules/backend`

## mirror

In addition to acting as a bastion host for all other instances, the `mirror` host serves all repos and packages used by other instances. It works similarly to the one for the libvirt backend, allowing instances in the private subnet to be completely disconnected from the Internet. The `mirror` host's data volume can be created from a prepopulated snapshot, which allows it to be operational without lengthy channel synchronization.

For instructions on how to refresh content in `mirror`~~, see comments in [modules/aws/mirror/main.tf](modules/aws/mirror/main.tf).

For instructions on how to set up a mirror data snapshot from scratch, see comments in [main.tf.aws-create-mirror-snapshot.example](main.tf.aws-create-mirror-snapshot.example).~~

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
