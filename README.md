# FRP Service

Prescriptive setup to get started publishing a private back-end service as a public endpoint using [frp proxy](https://gofrp.org/en/)

For an overview of FRP, see [FRP Architecture](https://github.com/fatedier/frp#architecture).

> FRP Architecture image from FRP repo
> ![FRP Architecture image from FRP repo](https://raw.githubusercontent.com/fatedier/frp/master/doc/pic/architecture.jpg?raw=true)


## Who this is for

* If you run a back-end server at home, and wish to publish it to the Internet, however your router is not assigned a public IP, because your ISP uses CG-NAT (Carrier Grade NAT), and you do not wish to acquire a public IP from the ISP,
* If you are able to run a small public cloud server / VPS, yet want to retain your main back-end server at home / "on-premises".

Then **frp** is an excellent option.

## About this project

This **FRP Service** project accelerates the deployment of [frp](https://gofrp.org/en/) in an opinionated way on [AWS EC2](https://aws.amazon.com/ec2/) using [Hashicorp Terraform](https://developer.hashicorp.com/terraform) for Infra-as-code automation.

### Project Structure
```
frp-service/
├── frp-client/          # Guidance to setup frpc on the back-end server
├── frp-server/          # Setup frps as the front-end proxy on AWS EC2 using Terraform scripts
└── README.md            # This file
