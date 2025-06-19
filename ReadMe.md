# README

# DevOps Assignment: Host Docker ROR Application with Nginx in AWS using IaC

## Introduction

This assignment aims to demonstrate the process of deploying a Dockerized Ruby on Rails application with Nginx in AWS with Loadbalancer and RDS using IaC.

### Guideline for the assignment submission

1. Fork this repo into your GitHub account. Setup the build process from the source code. Build process should generate a Docker image and upload it to AWS ECR.
2. Create a new folder named "infrastructure" in the root of the project and push your IaC code under this folder.
3. Prepare a Terraform/CloudFormation/CDK script to provision the scalable infrastructure in AWS ECS/EKS using this ECR image. You need to use ELB to distribute the traffic between servers. All the resources should be hosted in private subnet except load balancer.
4. The web application will integrate with database and S3. So you may need to create a RDS instance (Postgres) and S3 bucket and use them as ENV variable in ECS. Required ENV names will be mentioned in Github repo’s README. Application should integrate with S3 using IAM role authentication, not AccessKey and SecretKey. Application should integrate with RDS using database credentials (Host, DB name, Username and Password).
5. It should also contain a ReadMe file with cleardetails about how to use and create the Infrastructure with this IaC code.
6. Prepare an architecture diagram, deployment steps, and any other relevant information in the same folder.
7. Share a GitHub repository to Github account “Mallowtechdev” and send an email to HR team (hr@mallow-tech.com) about the completion along with Github repository link and branch details.


### Iac Structure

    ...
    ├── infrastructure
    │   ├──  ( # IaC Code files )
    │   │   ...
    │   │   ...
    │   ├──  ReadMe
    │   ├──  Architecture diagram
    │   ├──  Other documentation files
    │   ...              
    ...


### Prerequisites

1. AWS Account with appropriate permissions.
2. RDS Postgres 13.3 Database ( update the credentials in the below mentioned Environment variables)
3. LoadBalancer  ( update the loadbalancer endpoint in the environment variable)
4. Docker installed in your local machine.
5. Your preferred IaC tool ( Terraform, CDK, CloudFormation)
6. Other local tools if required.

### Version details:

* Ruby version - `3.2.2`
* Rails version - `7.0.5`
* Database - `Postgresql - 13.3`

### Docker conatiner details

* Rails container running in port 3000
* Nginx container running in port 80
* You can use the container alias name "rails_app" to for the nginx to send request to rails container


### Docker Folder Structure

    ...
    ├── docker
    │   ├── app
    │   │   ├── Dockerfile         # Rails container dockerfile
    │   │   └── entrypoint.sh      # Rails container entrypoint
    │   └── nginx
    │       ├── default.conf       # Nginx config file
    │       └── Dockerfile         # Nginx container dockerfile
    │                   
    ├── docker-compose.yml         # docker-compose file
    ...

### Environment variable for Ruby container

```env
RDS_DB_NAME="postgres database name"
RDS_USERNAME="postgres db user name"
RDS_PASSWORD="postgres db password"
RDS_HOSTNAME="postgres db hostname"
RDS_PORT="postgres db port"
S3_BUCKET_NAME="s3 bucket name"
S3_REGION_NAME="s3 region name"
LB_ENDPOINT="loadbalancer endpoint without http"
```

### Environment variable for Nginx container

```env
nil
```

### Note
This README is a guideline and should be adjusted based on your specific setup and requirements.
