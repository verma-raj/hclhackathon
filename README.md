# hclhackathon
This is a private repository which contains end to end deployment of an application
================================================================================

This repository will make a build , dockerize the build and passes through Sonarqube scanning and trivy scanning. It pushes the image to ECR and further deploys it to ECS with Fargate launch type. If this pipeline fails then will send the output to CICD agent for troubleshooting.


1. Configure EC2 instance for Jenkins agent 
2. Install jenkins
sudo apt install docker.io -y
sudo usermod -aG docker $USER
sudo docker pull jenkins/jenkins:lts
sudo mkdir -p jenkins_home
sudo chown ubuntu:ubuntu jenkins_home

3. Install python3 and pip3.
sudo apt install -y python3
sudo apt install -y python3-pip
sudo apt install -y python3-venv


4. Run Jenkins container
docker run -d --name jenkins \
  -p 8080:8080 \
  -p 50000:50000 \
  -v /home/ubuntu/jenkins_home:/var/jenkins_home \
  -v /usr/bin/python3:/usr/bin/python3 \
  -v /usr/lib/python3.12:/usr/lib/python3.12 \
  -v /var/run/docker.sock:/var/run/docker.sock \
  jenkins/jenkins:lts

5. Install Plugins in jenkins

6. Configure credentials
Create Jenkins API token, Go to right top corner user --> security --> Add New Token --> Name = jenkins-api-token, Copy the token and save
a. jenkins api in jenkins credentials
Go to jenkins credentials -> select 
Kind = username and Password
username = jenkisn username "jenkins"
ID = jenkins-api-token
password = < jenkins api token>

b. GitHub credentials in jenkins
Go to jenkins credentials -> 
Kind : Username and Password
Username: <user name of github>
ID : github-pat
Password: <git hub PAT token>

c. API gateway token

Kind: secret text
ID: apigw-ci-failure-key
secret : PAT token
Description : API GTW Key

7. Set up a multibranch pipeline with webhook with github
a. configure the jenkins url in github webhook
b. Go to new item -> give name  , Multibranch Pipeline --> give name Display Name, Branch Sources (Add source GitHub) -> Select credential (Github PAT) --> Repository HTTPS URL (github repo url) --> Behaviours ( strategy - All branches)  SAVE and APPLY




