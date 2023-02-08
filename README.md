# aws-cdk-wordpress

Sample CDK to deploy Wordpress in a EC2 with the following stack:
- NGINX
- PHP-FPM
- MariaDB
- TLS (self-signed)

# config
Edit `bin/aws-cdk-wordpress.js` and replace `FQDN` and `SSL.*` with desired values.

# notes
* by default the security group will only accept inbound connections from inside the VPC
* the secrets for Wordpress admin user and MySQL user are located at `/root`
* to connect in the EC2 use SSM (e.g.: `aws ssm start-session --target $INSTANCE_ID`)
* CDK will print the instance id after deployment

# deploy
```cdk deploy```

# cleanup
```cdk destroy```

