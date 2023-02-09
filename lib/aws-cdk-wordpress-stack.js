const fs = require('fs');
const cdk = require('aws-cdk-lib');
const ec2 = require('aws-cdk-lib/aws-ec2');
const iam = require('aws-cdk-lib/aws-iam');

const USER_DATA_FILE = 'lib/user-data.sh';

class AwsCdkWordpressStack extends cdk.Stack {
  /**
   * @param {cdk.App} scope
   * @param {string} id
   * @param {cdk.StackProps=} props
   */
  constructor(scope, id, props) {
    super(scope, id, props);

    const vpc = new ec2.Vpc(this, 'Vpc', {
      vpcName: 'wordpress',
      maxAzs: 2,
      subnetConfiguration: [
          {
              name: 'wordpress-public',
              subnetType: ec2.SubnetType.PUBLIC,
          }
      ]
  });

  const securityGroup = new ec2.SecurityGroup(this, 'WordpressSecurityGroup', {
      vpc: vpc,
      securityGroupName: 'wordpressSecurityGroup'
  });
  securityGroup.addIngressRule(ec2.Peer.ipv4(vpc.vpcCidrBlock), ec2.Port.tcp(443)); // all traffic inside VPC        

  const ami = new ec2.AmazonLinuxImage({
      generation: ec2.AmazonLinuxGeneration.AMAZON_LINUX_2,
      cpuType: ec2.AmazonLinuxCpuType.ARM_64
  });

  const userData = ec2.UserData.forLinux();
  for(const cmd of prepareUserDataCmds()) {
    userData.addCommands(cmd);
  }
  
  const role = new iam.Role(this, 'Ec2Role', {
      assumedBy: new iam.ServicePrincipal('ec2.amazonaws.com')
  })
  role.addManagedPolicy(iam.ManagedPolicy.fromAwsManagedPolicyName('AmazonSSMManagedInstanceCore'))

  const wordpressInstance = new ec2.Instance(this, 'WordpressInstance', {
      instanceName: 'wordpress',
      vpc: vpc,
      instanceType: ec2.InstanceType.of(ec2.InstanceClass.T4G, ec2.InstanceSize.SMALL),
      machineImage: ami,
      securityGroup: securityGroup,
      userData: userData,
      role: role
  });
  
  new cdk.CfnOutput(this, 'WordpressInstanceId', { value: wordpressInstance.instanceId });

  // read user data file and replace parameters with props values
  function prepareUserDataCmds() {
    let data = fs.readFileSync(USER_DATA_FILE, 'utf8');
    data = data.replace('FQDN=',`FQDN="${props.fqdn}"`);
    data = data.replace('ADMIN=',`ADMIN="${props.admin}"`);
    data = data.replace('SUBJECT=',`SUBJECT="${props.subject}"`);
    let lines = data.split('\n');

    return lines;
  }

  }
}

module.exports = { AwsCdkWordpressStack }
