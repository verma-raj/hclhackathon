pipeline {
    agent any

    environment {
        PATH = "${env.WORKSPACE}/aws-bin:${env.PATH}"
        dockerImage = "762682309545.dkr.ecr.us-east-1.amazonaws.com/hackathon:${env.BUILD_NUMBER}"
        trivyImage = 'aquasec/trivy:latest'
        trivyContainerName = 'trivy-container'
        TERRAFORM_VERSION = "1.14.4" 
        PROPS = readProperties file: 'hackathon.properties'
    }

    stage('Load Properties') {
        steps {
            script {
                def props = readProperties file: 'hackathon.properties'
                env.SONAR_HOST_URL = props.SONAR_HOST_URL.replaceAll(/^"|"$/, '')  // removes quotes if present
            }
        }
    }


    stages {
         stage('Install Terraform') {
            steps {
                script {
                    // Ensure Terraform version is correctly set
                    if (!env.TERRAFORM_VERSION) {
                        error "Terraform version is not specified!"
                    }

                    echo 'Installing Terraform locally in the workspace...'
                    sh '''
                        # Set the Terraform version to download
                        TERRAFORM_VERSION=${TERRAFORM_VERSION}

                        # Download Terraform binary
                        curl -LO https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        
                        # Unzip the downloaded file
                        unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        
                        # Move terraform binary to workspace (no need for sudo)
                        #mv terraform ${WORKSPACE}/terraform

                        # Clean up the downloaded zip file
                        rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

                        # Verify Terraform installation locally
                        ${WORKSPACE}/terraform -version
                    '''
                }
            }
        }
        stage('Check AWS CLI') {
            steps {
                script {
                    def awsExists = sh(script: "command -v aws >/dev/null 2>&1", returnStatus: true) == 0
                    if (!awsExists) {
                        echo "AWS CLI not found, installing..."
                        // Install AWS CLI only if not already installed
                        sh '''
                            set -e
                            if [ ! -x "$WORKSPACE/aws-bin/aws" ]; then
                                rm -rf aws awscliv2.zip
                                curl -sSL https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip -o awscliv2.zip
                                unzip -oq awscliv2.zip
                                ./aws/install --install-dir "$WORKSPACE/aws-cli" --bin-dir "$WORKSPACE/aws-bin"
                                rm -rf aws awscliv2.zip
                            fi
                            aws --version
                        '''
                    } else {
                        echo "AWS CLI already installed."
                    }
                }
            }
        }

        stage('Git Checkout') {
            steps {
                echo "Checkout the code"
                checkout scm
            }
        }

        stage('Build App') {
            steps {
                echo "Compile the project"
            }
        }

        stage('Build Docker Image') {
            steps {
                dir('infra') {
                    echo "==> Building Docker image"
                    sh "docker build -t ${dockerImage} -f Dockerfile ."
                    echo "==> Completed building Docker image"
                }
            }
        }

      stage('SonarQube Analysis') {
            steps {
                withCredentials([string(credentialsId: 'sonar-token', variable: 'SONAR_TOKEN')]) {
                    echo 'Running SonarQube scan using Docker...'
                    sh '''
                        docker run --rm \
                            -v $(pwd):/project \
                            -e SONAR_TOKEN=$SONAR_TOKEN \
                            sonarsource/sonar-scanner-cli \
                            sonar-scanner \
                            -Dsonar.projectKey=hclhackathon \
                            -Dsonar.sources=. \
                            -Dsonar.host.url="$SONAR_HOST_URL" \
                            -Dsonar.token=$SONAR_TOKEN
                    '''
                }
            }
        }

        stage('Run Trivy Scan') {
            steps {
                echo "Running Trivy scan on the Docker image"
                sh """
                    docker run \
                        --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        -v ${WORKSPACE}:/workspace \
                        ${trivyImage} image --format json ${dockerImage} > trivy-report.json
                """
                archiveArtifacts artifacts: '**/trivy-report.json', allowEmptyArchive: true
            }
        }
        
       
        stage('Publish to ECR') {
            steps {
                withAWS(credentials: 'aws-user', region: 'us-east-1') {
                    sh '''
                        aws ecr get-login-password --region us-east-1 \
                        | docker login --username AWS --password-stdin 762682309545.dkr.ecr.us-east-1.amazonaws.com
                    '''
                    sh "docker push ${dockerImage}"

                    sh """
                        aws ssm put-parameter \
                        --name "/hclhackathon/dev/docker_image" \
                        --type "String" \
                        --value "${dockerImage}" \
                        --overwrite \
                        --region us-east-1
                    """
                }
            }
        }

 	stage(' Terraform Init '){
            steps{
                echo 'Initializing Terraform'
                 withAWS(credentials: 'aws-user', region: 'us-east-1') {
                      //  echo "$AWS_ACCESS_KEY $AWS_SECRET_KEY $AWS_REGION" 
			     sh ' cd infra/  &&  ${WORKSPACE}/terraform init '
                        
               
                }
            }
        }
        
    stage(' Terraform Validate '){
            steps{
                echo 'Validating Terraform'
                 withAWS(credentials: 'aws-user', region: 'us-east-1') {
                      //  echo "$AWS_ACCESS_KEY $AWS_SECRET_KEY $AWS_REGION" 
			     sh ' cd infra/ && ${WORKSPACE}/terraform validate'
                        
               }
            }
        }
    stage(' Terraform Plan '){
            steps{
                echo 'Running Terraform Plan'
                 withAWS(credentials: 'aws-user', region: 'us-east-1') {
                      //  echo "$AWS_ACCESS_KEY $AWS_SECRET_KEY $AWS_REGION" 
			     sh 'cd infra/ && ${WORKSPACE}/terraform plan'
                        
               }
            }
        }
        
    stage(' Terraform Deploy '){
            steps{
                echo 'Deploying Infrastructure'
                 withAWS(credentials: 'aws-user', region: 'us-east-1') {
                      //  echo "$AWS_ACCESS_KEY $AWS_SECRET_KEY $AWS_REGION" 
			     sh 'cd infra/ && ${WORKSPACE}/terraform apply --auto-approve'
                        
               }
            }
        }
  
    }

    post {
        always {
            echo "Cleaning up workspace"
            //cleanWs()
        }
    }
}
