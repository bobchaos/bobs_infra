# bobs\_infra
Experiments with Cinc, TF12, and whatever catches my attention. Not intended for distribution, and as such I'm playing fast and loose with my devlopment practices, but you're welcome to fork or copy pieces.

## General Functioning and caveats

At this time, this consists mostly of terraform code intended to create a lab from scratch, and toss it when I'm done for the day. Things that do not conflict with that notion will ere on the side of "Enterprise Grade", to the best of my abilities.

It leverages the [aws_vpc module](https://registry.terraform.io/modules/terraform-aws-modules/vpc/aws/2.24.0) by Anton Babenko to create a standard VPC (public and private subnets in 3 AZs and all things required for that to function.

Inside that VPC, it creates a bastion instance and a Goiardi server. As of this writting the Goiardi server doesn't actually work, it's missing it's database schema in postgres (but someone could easily ditch postgres and use local file storage). Both instances are self-healing (See the embedded aws-self-healer module, which I may eventually publish when I'm satisfied all 4 topologies work as intended), but at this time do not have health checks in place, or provisions for it in the module. Until I do add health checks, they'd nonetheless restore themselves, complete with all statefull data, EIPs and any EBS volumes should AWS hardware fail or something such.

The Goiardi server is configured using a cinc-zero artifact thats included in this repository. All secrets are generated by terraform at runtime (except an initial keypair and IAM user to execute with), stored in ASM and retrieved from there by Cinc. The Cinc-zero artifact is based on [cinc-goiardi](https://gitlab.com/cinc-project/cinc-goiardi-cookbook), a cookbook I maintain for the Cinc Project.

The bastion currently has no configuration, but I'm likely to add a hardening policy based on the works of the folks at [Dev-Sec](https://github.com/dev-sec/) once Goiardi is able to serve cookbooks.

All IAM permissions are given using the principle of least privilege. Networking permissions are a bit looser so I can demo this from anywhere, and because writting egress rules is no fun :/

Code is tested using kitchen-terraform and github actions.

Testing is performed with Chef Inspec&trade; , used under license as I have no commercial purposes and this is a lab. Businesses looking to fork will want to take that into consideration. The testing suite is incomplete as of this writting but I'm planning on catching it up soonish.

## Running
`terraform apply --var-file="./priv.tfvars"`

where priv.tfvars contains your SSH keypair name and a password to inject as the master PW for the DB:

```
key_name   = "my_ec2_keypair"
main_db_pw = "PickSomethingReallyDifficult!"
```

Terraform kicks off everything at this time. Default parameters create an infrastrcture that can be destroyed with no leftovers, but most critical assets are tied to the terraform variable "protect_assets", which you could set to true to enable things like database protection and EBS volume preservation.

There are more TF variables to control behavior, but those are self-documenting, see variables.tf.

## Testing
`kitchen test` and enjoy!

## Contributing
This is a just-for-fun project, so I'm not really taking contributions or intend on maintaining it "properly", but if someone's interested in doing that I'd happily contribute to a fork. Do feel free to open issues tho, I'll do my best to address them, provided it's interesting to me o.O

## License
[Apache2.0](https://www.apache.org/licenses/LICENSE-2.0)
