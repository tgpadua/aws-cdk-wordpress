#!/usr/bin/env node
const cdk = require('aws-cdk-lib');
const { AwsCdkWordpressStack } = require('../lib/aws-cdk-wordpress-stack');

const FQDN = 'mydomain.com';
const SSL = {
    COUNTRY: 'US',
    STATE: 'CA',
    LOCATION: 'Santa Clara',
    ORG: 'Company Inc.',
    OU: 'IT'
}

const SUBJECT = `/C=${SSL.COUNTRY}/ST=${SSL.STATE}/L=${SSL.LOCATION}/O=${SSL.ORG}/OU=${SSL.OU}/CN=${FQDN}`;


const app = new cdk.App();
new AwsCdkWordpressStack(app, 'AwsCdkWordpressStack', {
    fqdn: FQDN,
    subject: SUBJECT
});
