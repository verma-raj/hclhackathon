pipeline {
    agent any

    environment {
        PATH = "${env.WORKSPACE}/aws-bin:${env.PATH}"
        TERRAFORM_VERSION = "1.14.4"
        // API Gateway endpoint (your manual command uses this)
        CI_FAILURE_API_URL = "https://01ul4tueeh.execute-api.us-east-1.amazonaws.com/prod/ci-failure"
    }

    stages {
        stage ('Load Properties') {
            steps {
                script {
                    def props = readProperties file: 'hackathon.properties'
                    env.SONAR_HOST_URL       = props.SONAR_HOST_URL?.replaceAll(/^"|"$/, '')
                    env.TRIVY_CONTAINER_NAME = props.TRIVY_CONTAINER_NAME?.replaceAll(/^"|"$/, '')
                    env.TRIVY_IMAGE          = props.TRIVY_IMAGE?.replaceAll(/^"|"$/, '')
                    def repo                 = props.ECR_REPO?.replaceAll(/^"|"$/, '')
                    env.DOCKER_IMAGE         = "${repo}:${env.BUILD_NUMBER}"
                }
            }
        }

        stage('Install Terraform') {
            steps {
                script {
                    if (!env.TERRAFORM_VERSION) {
                        error "Terraform version is not specified!"
                    }

                    echo 'Installing Terraform locally in the workspace...'
                    sh '''
                        set -e
                        TERRAFORM_VERSION=${TERRAFORM_VERSION}

                        curl -sS -LO https://releases.hashicorp.com/terraform/$TERRAFORM_VERSION/terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        unzip -o terraform_${TERRAFORM_VERSION}_linux_amd64.zip
                        rm terraform_${TERRAFORM_VERSION}_linux_amd64.zip

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
                        set -e
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
                    set -e
                    docker run --rm \
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
                        set -e
                        aws ecr get-login-password --region us-east-1 \
                        | docker login --username AWS --password-stdin 762682309545.dkr.ecr.us-east-1.amazonaws.com
                    '''
                    sh "docker push ${DOCKER_IMAGE}"

                    sh """
                        set -e
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
            steps {
                echo 'Initializing Terraform'
                withAWS(credentials: 'aws-user', region: 'us-east-1') {
                    sh 'cd infra/ && ${WORKSPACE}/terraform init'
                }
            }
        }

        stage(' Terraform Lint ') {
            steps {
                echo 'Terraform Lint'
                withAWS(credentials: 'aws-user', region: 'us-east-1') {
                    sh 'cd infra/ && tflint --init && tflint --recursive --format=compact'
                }
            }
        }

        stage(' Terraform Validate ') {
            steps {
                echo 'Validating Terraform'
                withAWS(credentials: 'aws-user', region: 'us-east-1') {
                    sh 'cd infra/ && ${WORKSPACE}/terraform validate'
                }
            }
        }

        stage(' Terraform Plan ') {
            steps {
                echo 'Running Terraform Plan'
                withAWS(credentials: 'aws-user', region: 'us-east-1') {
                    sh 'cd infra/ && ${WORKSPACE}/terraform plan'
                }
            }
        }

        stage(' Terraform Deploy ') {
            steps {
                echo 'Deploying Infrastructure'
                withAWS(credentials: 'aws-user', region: 'us-east-1') {
                    sh 'cd infra/ && ${WORKSPACE}/terraform apply --auto-approve'
                }
            }
        }
    }

    post {
        failure {
            script {
                echo "Pipeline failed — running API Gateway → pre-signed URL → upload console log workflow..."
                // Create a deterministic filename in workspace (since Jenkins does not create one by default)
                def safeJobName = (env.JOB_NAME ?: "job").replaceAll(/[\\/]/, "_")
                def logFile = "console-output-${safeJobName}-${env.BUILD_NUMBER}.log"
                // Wrap in try/catch so this handler doesn't hide the original failure
                try {
                    // 1) Download console output to file (no rawBuild usage → no sandbox issues)
                    withCredentials([usernamePassword(credentialsId: 'jenkins-api-token',
                                                      usernameVariable: 'JENKINS_USER',
                                                      passwordVariable: 'JENKINS_TOKEN')]) {
                        sh """
                            set -e
                            echo "Downloading console output from: ${BUILD_URL}consoleText"
                            curl -sS --fail -u "${JENKINS_USER}:${JENKINS_TOKEN}" \
                              "${BUILD_URL}consoleText" \
                              -o "${logFile}"
                        """
                    }

                    archiveArtifacts artifacts: "${logFile}", allowEmptyArchive: true
                    
                    // 2) Invoke API Gateway exactly like your manual call (POST, content-type, x-api-key, no body)
                    withCredentials([string(credentialsId: 'apigw-ci-failure-key', variable: 'API_GW_KEY')]) {

                        def response = sh(
                            returnStdout: true,
                            script: """
                                set -e
                                curl -sS --fail -X POST "${env.CI_FAILURE_API_URL}" \
                                  -H "Content-Type: application/json" \
                                  -H "x-api-key:${API_GW_KEY}"
                            """
                        ).trim()

                        echo "API Gateway response: ${response}"

                        // 3) Parse response for upload instructions: upload.url, upload.method, upload.headers
                        def parsed = new groovy.json.JsonSlurperClassic().parseText(response)

                        // In case the API is Lambda-proxy style and wraps JSON in "body"
                        if (parsed?.body instanceof String) {
                            parsed = new groovy.json.JsonSlurperClassic().parseText(parsed.body)
                        }

                        def upload = parsed.upload
                        if (!upload?.url) {
                            error "API response did not contain upload.url. Full response: ${response}"
                        }

                        def presignedUrl = upload.url
                        def method = upload.method ?: "PUT"
                        def headers = upload.headers ?: ["Content-Type": "text/plain"]

                        // Optional: show S3 key returned by API
                        if (parsed?.s3?.key) {
                            echo "S3 object key from API: ${parsed.s3.key}"
                        }

                        // Build curl header arguments
                        def headerArgs = headers.collect { k, v -> "-H \"${k}: ${v}\"" }.join(' ')

                        // 4) Upload the console log using the pre-signed URL (method/headers from API)
                        sh """
                            set -e
                            echo "Uploading ${logFile} to S3 using presigned URL (method: ${method})..."
                            curl -sS --fail -X ${method} ${headerArgs} \
                              --upload-file "${logFile}" \
                              "${presignedUrl}"
                            echo "Upload complete."
                        """
                    }

                } catch (err) {
                    echo "WARNING: Post-failure upload flow failed: ${err}"
                    echo "Continuing so the original pipeline failure remains the main failure reason."
                }
            }
        }

        always {
            echo "Cleaning up workspace"
            // cleanWs()
        }
    }
}