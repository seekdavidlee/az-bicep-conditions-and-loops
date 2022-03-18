# Introduction
This is part of a demo series on DevOps. In this project, we are focused on designing a 2 VNETS which are paired with one being the primary and the other for DR purposes. We will learn about the concepts of how to write conditions and perform iterative loops to build subnets for example.

![Architecture](/Architecture/Networks.png)

# Steps
We have created a bicep file and we are ready to deploy. Let's launch CloudShell and clone this repo there.

1. Create resource group with the following command ``` az group create --name bicep-demo --location centralus ``` 
2. Configure your variables ``` $SourceIP="<Office Source IP>";$prefix=<Some prefix value for your resource names>" ```
3. Next, let's deploy this into the resource group ``` az deployment group create -n deploy-1 -g bicep-demo --template-file deploy.bicep --parameters stackPrefix=$prefix stackEnvironment=dev sourceIP=$SourceIP ```