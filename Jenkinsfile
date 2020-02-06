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
    ),
    containerTemplate(
            name: 'docker',
            image: 'docker:18.09.7-dind',
            ttyEnabled: true,
            resourceLimitCpu: '400m',
            resourceLimitMemory: '512Mi',
            resourceRequestCpu: '200m',
            resourceRequestMemory: '256Mi',
            privileged: true,
            envVars: [
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
                  ng build
                  npm publish --registry http://admin:$(echo -ne $NEXUS_ADMIN_PASS)@sonatype-nexus-service:8081/repository/npm
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
                  echo "sonarUser="$SONAR_USER >> python/application.properties
                  echo "sonarCredentials="$SONAR_PASS >> python/application.properties
                  python python/qamera.py python/application.properties spring-petclinic-angular
                  '''
              }
            }
        }
        stage('DinD') {
            container('docker') {
              stage('Docker Build') {
                  sh '''
                  apk --update add curl
                  curl "http://admin:$NEXUS_ADMIN_PASS@nexus.eks.minlab.com/repository/npm/spring-petclinic-angular/-/spring-petclinic-angular-8.0.1.tgz" --output spring-petclinic-angular-8.0.1.tgz
                  docker build -t petclinic_front:latest .
                  '''
              }
              stage('Docker tag and push') {
                  sh '''
                  tag_nexus=$(date +%s) && docker tag petclinic_front:latest docker.eks.minlab.com/repository/docker-registry/petclinic_front:${tag_nexus}
                  docker login http://docker.eks.minlab.com -uadmin -p$(echo -ne $NEXUS_ADMIN_PASS)
                  docker push docker.eks.minlab.com/repository/docker-registry/petclinic:${tag_nexus}
                  '''
              }
            }
        }
    }
}
