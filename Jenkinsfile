pipeline {
    agent any

    environment {
        PATH = "${env.WORKSPACE}/aws-bin:${env.PATH}"
        TERRAFORM_VERSION = "1.14.4" 
    }

    stages {
        stage ('Load Properties') {
            steps {
                script {
                    def props = readProperties file: 'hackathon.properties'
                    env.SONAR_HOST_URL = props.SONAR_HOST_URL.replaceAll(/^"|"$/, '')  // removes quotes if present
                    env.TRIVY_CONTAINER_NAME = props.TRIVY_CONTAINER_NAME.replaceAll(/^"|"$/, '') 
                    env.TRIVY_IMAGE = props.TRIVY_IMAGE.replaceAll(/^"|"$/, '')
                    def repo = props.ECR_REPO.replaceAll(/^"|"$/, '')
                    env.DOCKER_IMAGE = "${repo}:${env.BUILD_NUMBER}"
                   
                    

                }
            }
        }


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
                    sh "docker build -t ${DOCKER_IMAGE} -f Dockerfile ."
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
                        ${TRIVY_IMAGE} image --format json ${DOCKER_IMAGE} > trivy-report.json
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
                    sh "docker push ${DOCKER_IMAGE}"

                    sh """
                        aws ssm put-parameter \
                        --name "/hclhackathon/dev/docker_image" \
                        --type "String" \
                        --value "${DOCKER_IMAGE}" \
                        --overwrite \
                        --region us-east-1
                    """

                }
            }
        }

 	    stage(' Terraform Init ') {
            steps{
                echo 'Initializing Terraform'
                 withAWS(credentials: 'aws-user', region: 'us-east-1') {
                      //  echo "$AWS_ACCESS_KEY $AWS_SECRET_KEY $AWS_REGION" 
			     sh ' cd infra/  &&  ${WORKSPACE}/terraform init '
                        
               
                }
            }
        }

        stage(' Terraform Lint ') {
            steps{
                echo 'Terraform Lint'
                 withAWS(credentials: 'aws-user', region: 'us-east-1') {
                      //  echo "$AWS_ACCESS_KEY $AWS_SECRET_KEY $AWS_REGION" 
			     sh ''' cd infra/  &&  tflint --init &&  tflint --recursive --format=compact'''
               }
            }
       }

       stage(' Terraform Validate ') {
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
    // ✅ New: when pipeline fails, call API GW and upload console log
        failure {
            script {
                echo "Pipeline failed — invoking API Gateway and uploading console output to S3 via pre-signed URL..."

                // 1) Capture console output into a file
                // Note: currentBuild.rawBuild may require Script Approval depending on your Jenkins security settings
                def maxLines = (env.MAX_LOG_LINES ?: "20000") as Integer
                def logText  = currentBuild.rawBuild.getLog(maxLines).join("\n")
                writeFile file: "cicd-console-output.log", text: logText
                archiveArtifacts artifacts: "cicd-console-output.log", allowEmptyArchive: true

                // 2) Call API Gateway to get pre-signed URL
                // Store API key in Jenkins Credentials (Secret text) with ID: apigw-ci-failure-key
                withCredentials([string(credentialsId: 'apigw-ci-failure-key', variable: 'API_GW_KEY')]) {

                    // Prepare a payload (adjust fields if your API expects different input)
                    def objectKey = "${env.JOB_NAME}/${env.BUILD_NUMBER}/console-output.log"
                    def payload = groovy.json.JsonOutput.toJson([
                        jobName     : env.JOB_NAME,
                        buildNumber : env.BUILD_NUMBER,
                        buildUrl    : env.BUILD_URL,
                        bucket      : env.FAILURE_BUCKET,
                        objectKey   : objectKey
                    ])

                    writeFile file: "ci-failure-payload.json", text: payload

                    def response = sh(
                        returnStdout: true,
                        script: """
                            set -e
                            curl -sS -X POST "${env.CI_FAILURE_API_URL}" \
                              -H "Content-Type: application/json" \
                              -H "x-api-key: ${API_GW_KEY}" \
                              --data @ci-failure-payload.json
                        """
                    ).trim()

                    echo "API Gateway response received."

                    // 3) Parse response for the pre-signed URL (support common field names)
                    def json = new groovy.json.JsonSlurperClassic().parseText(response)
                    def presignedUrl = json.presignedUrl ?: json.url ?: json.uploadUrl

                    if (!presignedUrl) {
                        error "API did not return a presigned URL. Response: ${response}"
                    }

                    // 4) Upload log file to S3 using pre-signed URL (usually PUT)
                    sh """
                        set -e
                        curl -sS -X PUT \
                          -H "Content-Type: text/plain" \
                          --upload-file cicd-console-output.log \
                          "${presignedUrl}"
                    """

                    echo "Console output uploaded successfully to S3 (via pre-signed URL)."
                }
            }
        }

        always {
            echo "Cleaning up workspace"
            //cleanWs()
        }
    }
}
