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
            echo "Pipeline failed — running API Gateway → presigned URL → upload console log workflow..."

            // Jenkins does NOT create a default console log file in workspace, so we create one.
            def safeJobName = (env.JOB_NAME ?: "job").replaceAll(/[\\/]/, "_")
            def logFile = "console-output-${safeJobName}-${env.BUILD_NUMBER}.log"

            try {
                // 1) Download console output as a file (no rawBuild -> no sandbox approvals needed)
                withCredentials([usernamePassword(credentialsId: 'jenkins-api-token', passwordVariable: 'JENKINS_TOKEN', usernameVariable: 'JENKINS_USER')]) {

                withEnv(["LOG_FILE=${logFile}", "CONSOLE_URL=${env.BUILD_URL}consoleText"]) {
                    sh '''#!/bin/bash
                      set -euo pipefail
                      echo "Downloading console output from: ${CONSOLE_URL}"

                    # NOTE: Using shell variable expansion avoids Groovy secret interpolation warnings
                    curl -sS --fail -u "$JENKINS_USER:$JENKINS_TOKEN" \
                    "${CONSOLE_URL}" \
                    -o "${LOG_FILE}"

                    echo "Console log saved to ${LOG_FILE}"
                '''
          }
        }

        archiveArtifacts artifacts: logFile, allowEmptyArchive: true

        // 2) Invoke API Gateway exactly like your manual curl (POST, headers only)
        withCredentials([string(credentialsId: 'apigw-ci-failure-key', variable: 'API-GTW-KEY')]) {
          def response = sh(
            returnStdout: true,
            script: '''#!/bin/bash
              set -euo pipefail
              curl -sS --fail -X POST "https://01ul4tueeh.execute-api.us-east-1.amazonaws.com/prod/ci-failure" \
                -H "Content-Type: application/json" \
                -H "x-api-key:$API_GTW_KEY"
            '''
          ).trim()

          // 3) Parse response: upload.url, upload.method, upload.headers (your actual schema)
          def parsed = new groovy.json.JsonSlurperClassic().parseText(response)

          // Handle Lambda-proxy style: { "body": "{...json...}" }
          if (parsed?.body instanceof String) {
            parsed = new groovy.json.JsonSlurperClassic().parseText(parsed.body)
          }

          def uploadUrl = parsed?.upload?.url
          def method    = parsed?.upload?.method ?: "PUT"
          def headers   = parsed?.upload?.headers ?: ["Content-Type": "text/plain"]

          if (!uploadUrl) {
            error "API did not return upload.url. Response was: ${response}"
          }

          // Do NOT echo the full presigned URL (it contains security token + signature)
          echo "Got presigned upload instructions from API Gateway (method: ${method})."
          if (parsed?.s3?.key) {
            echo "Target S3 key: ${parsed.s3.key}"
          }

          // Build curl header arguments safely
          // (Values unlikely to contain quotes; if they do, we can harden escaping)
          def headerArgs = headers.collect { k, v -> "-H '${k}: ${v}'" }.join(' ')

          // 4) Upload log to S3 using presigned URL (method + headers from API)
          withEnv(["LOG_FILE=${logFile}", "UPLOAD_URL=${uploadUrl}", "METHOD=${method}", "HEADER_ARGS=${headerArgs}"]) {
            sh '''#!/bin/bash
              set -euo pipefail
              echo "Uploading ${LOG_FILE} via presigned URL..."

              # HEADER_ARGS contains quoted -H arguments; use eval for correct expansion
              eval curl -sS --fail -X "$METHOD" $HEADER_ARGS \
                --upload-file "$LOG_FILE" \
                "$UPLOAD_URL"

              echo "Upload completed."
            '''
          }
        }

      } catch (err) {
        // Important: don't hide the original pipeline failure
        echo "WARNING: Post-failure upload flow failed: ${err}"
        echo "Continuing so original pipeline failure remains visible."
      }
    }
  }

  always {
    echo "Cleaning up workspace"
    // cleanWs()
  }
}
}