podTemplate(label: 'jnlp-petclinic-front', serviceAccount: 'jenkins', slaveConnectTimeout: '600', containers: [
    containerTemplate(
            name: 'npm',
            image: 'node:13.7.0-stretch',
            ttyEnabled: true,
            resourceLimitCpu: '1000m',
            resourceLimitMemory: '1500Mi',
            resourceRequestCpu: '250m',
            resourceRequestMemory: '256Mi',
            command: 'cat',
            envVars: [
                secretEnvVar(key: 'SONAR_URL', secretName: 'sonar-petclinic', secretKey: 'url'),
                secretEnvVar(key: 'SONAR_USER', secretName: 'sonar-petclinic', secretKey: 'username'),
                secretEnvVar(key: 'SONAR_PASS', secretName: 'sonar-petclinic', secretKey: 'password'),
                secretEnvVar(key: 'NEXUS_ADMIN_PASS', secretName: 'nexus-petclinic', secretKey: 'password')
            ]
    ),
    containerTemplate(
            name: 'python',
            image: 'python:3.7.6-alpine3.10',
            ttyEnabled: true,
            command: 'cat',
            resourceLimitCpu: '400m',
            resourceLimitMemory: '512Mi',
            resourceRequestCpu: '200m',
            resourceRequestMemory: '256Mi',
            privileged: true,
            envVars: [
                secretEnvVar(key: 'SONAR_URL', secretName: 'sonar-petclinic', secretKey: 'url'),
                secretEnvVar(key: 'SONAR_USER', secretName: 'sonar-petclinic', secretKey: 'username'),
                secretEnvVar(key: 'SONAR_PASS', secretName: 'sonar-petclinic', secretKey: 'password'),
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
                  export CHROME_BIN=chromium
                  apt-get update
                  apt-get install -y chromium
                  npm uninstall -g angular-cli @angular/cli
                  npm cache clean --force
                  npm install -g @angular/cli@latest
                  npm install
                  npm i -D handlebars@4.5.0
                  npm test
                  '''
              }
              stage('Publishing to Nexus') {
                  sh '''#!/bin/bash
                  npm publish --registry http://admin:$(echo -ne $NEXUS_ADMIN_PASS)@nexus-sonatype-nexus-new:8081/repository/npm
                  '''
              }
              stage('Sonar') {
                  sh '''#!/bin/bash
                  #sed -i "s/application_name/$(grep "name" package.json | awk -F\" '{print $4}')/g" sonar-project.properties
                  #sed -i "s/application_version/$(grep "version" package.json | awk -F\" '{print $4}')/g" sonar-project.properties
                  npm install -D sonarqube-scanner
                  npm run sonar
                  '''
              }
            }
        }
        stage('Send Sonar data to InfluxDB') {
            container('python') {
              stage('Send Sonar data to InfluxDB') {
                  sh '''
                  python3 -m pip install influxdb
                  apk --update add git less openssh
                  cd /tmp && git clone https://github.com/overflow15/sonarqube-influxdb.git
                  cd sonarqube-influxdb
                  sed -i "s/sonarURL=/sonarURL=$SONAR_URL/g" application.properties
                  sed -i "s/sonarUser=/sonarUser=$SONAR_USER/g" application.properties
                  sed -i "s/sonarCredentials=/sonarCredentials=$SONAR_PASS/g" application.properties
                  python /tmp/sonarqube-influxdb/qamera.py /tmp/sonarqube-influxdb/python/application.properties spring-petclinic-angular
                  '''
              }
            }
        }
    }
}
