podTemplate(label: 'jnlp-petclinic-front', serviceAccount: 'jenkins', slaveConnectTimeout: '600', containers: [
    containerTemplate(
            name: 'npm',
            image: 'npm',
            ttyEnabled: true,
            resourceLimitCpu: '1000m',
            resourceLimitMemory: '768Mi',
            resourceRequestCpu: '250m',
            resourceRequestMemory: '256Mi',
            command: 'cat',
            envVars: [
                secretEnvVar(key: 'SONAR_URL', secretName: 'sonar-petclinic', secretKey: 'url'),
                secretEnvVar(key: 'SONAR_USER', secretName: 'sonar-petclinic', secretKey: 'username'),
                secretEnvVar(key: 'SONAR_PASS', secretName: 'sonar-petclinic', secretKey: 'password'),
                secretEnvVar(key: 'NEXUS_ADMIN_PASS', secretName: 'nexus-petclinic', secretKey: 'password')
            ]
    )
    ]
)
{
    node('jnlp-petclinic-front') {
        stage('Checkout') {
            checkout scm
            container('npm') {
              stage('Unit tests') {
                  sh '''#!/bin/bash
                  export NG_CLI_ANALYTICS=ci
                  apt-get update
                  apt-get install -y chromium
                  cd spring-petclinic-angular
                  npm uninstall -g angular-cli @angular/cli
                  npm cache clean --force
                  npm install -g @angular/cli@latest
                  npm install
                  npm i -D handlebars@4.5.0
                  npm test
                  '''
              }
              stage('Compiling') {
                  sh '''#!/bin/bash
                  ng build
                  npm publish --registry http://admin:$(echo -ne $NEXUS_ADMIN_PASS)@nexus.eks.minlab.com/repository/npm
                  '''
              }
            }
        }