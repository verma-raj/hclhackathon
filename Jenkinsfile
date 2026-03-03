pipeline {
    agent any

    environment {
        PATH = "${env.WORKSPACE}/aws-bin:${env.PATH}"
        TERRAFORM_VERSION = "1.14.4"
        // API Gateway endpoint (your manual command uses this)
        //CI_FAILURE_API_ENDPOINT = ""
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
                    env.CI_FAILURE_API_ENDPOINT = props.CI_FAILURE_API_ENDPOINT?.replaceAll(/^"|"$/, '')?.trim()
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
                    def pyExists = sh(script: "command -v python3 >/dev/null 2>&1", returnStatus: true) == 0
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
                   
                   if (!pyExists) { 
                       echo "Python not found, installing..." 
                       
                   } else {
                        echo "Python already installed."
                        sh '''python3 --version
                        '''
                        
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
                
                		echo "JENKINS_USER set? " + (env.JENKINS_USER ? "YES" : "NO")
				echo "JENKINS_TOKEN set? " + (env.JENKINS_TOKEN ? "YES" : "NO")
				
                    sh '''#!/bin/bash
                      set -euo pipefail
                      echo "Downloading console output from: ${CONSOLE_URL}"
                      
      		# 1) Clean token (removes hidden CR/LF that causes 401)
      			JENKINS_TOKEN_CLEAN="$(printf "%s" "$JENKINS_TOKEN" | tr -d '\r\n')"
      			
      			JENKINS_BASE="$(echo "${CONSOLE_URL}" | sed -E 's#(https?://[^/]+)/.*#\\1#')"
				echo "STEP DEBUG 1: Jenkins base detected: ${JENKINS_BASE}"
				

      		# 2) Preflight: validate auth in the SAME pipeline context (no secrets printed)
      			
				WHOAMI_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
      				--connect-timeout 10 --max-time 30 \
        				-u "$JENKINS_USER:$JENKINS_TOKEN_CLEAN" \
        				"${JENKINS_BASE}/whoAmI/api/json")
      				echo "whoAmI HTTP status: ${WHOAMI_CODE}"

      		# 3) Preflight: validate consoleText access before download
      				CONSOLE_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
        				-u "$JENKINS_USER:$JENKINS_TOKEN_CLEAN" \
        				"${CONSOLE_URL}")
      			echo "consoleText HTTP status: ${CONSOLE_CODE}"

      		if [ "${CONSOLE_CODE}" != "200" ]; then
        			echo "consoleText request failed with HTTP ${CONSOLE_CODE}"
        			exit 22
      		fi
      
      
 			# 4) Download the consoleText
      				curl -sS --fail \
        				-u "$JENKINS_USER:$JENKINS_TOKEN_CLEAN" \
        				"${CONSOLE_URL}" \
        				-o "${LOG_FILE}"

      		echo "Console log saved to ${LOG_FILE}"

    		'''
          }
        }

        archiveArtifacts artifacts: logFile, allowEmptyArchive: true

        // 2) Invoke API Gateway exactly like your manual curl (POST, headers only)
        withCredentials([string(credentialsId: 'apigw-ci-failure-key', variable: 'API_GTW_KEY')]) {
        withEnv(["LOG_FILE=${logFile}", "API_ENDPOINT=${env.CI_FAILURE_API_ENDPOINT}"]){
        
			sh '''#!/bin/bash
                set -euo pipefail
                set +x

                echo "Calling API Gateway: ${API_ENDPOINT}"

                # API GW call (same as your manual curl)
                curl -sS --fail -X POST "${API_ENDPOINT}" \
                  -H "Content-Type: application/json" \
                  -H "x-api-key:${API_GTW_KEY}" \
                  -o apigw-response.json

                # Parse JSON using python3 to avoid Jenkins Groovy sandbox restrictions
                python3 - <<'PY'
import json, sys

with open("apigw-response.json", "r", encoding="utf-8") as f:
    data = json.load(f)

# Handle Lambda proxy integration: {"body":"{...}"}
if isinstance(data, dict) and isinstance(data.get("body"), str):
    data = json.loads(data["body"])

upload = (data or {}).get("upload") or {}
url = upload.get("url")
method = upload.get("method") or "PUT"
headers = upload.get("headers") or {"Content-Type": "text/plain"}

if not url:
    print("ERROR: upload.url missing in API response", file=sys.stderr)
    print(json.dumps(data)[:2000], file=sys.stderr)
    sys.exit(2)

# Write values to files
with open("upload_url.txt", "w", encoding="utf-8") as f: f.write(url)
#with open("upload_method.txt", "w", encoding="utf-8") as f: f.write(method)
with open("upload_method.txt", "w", encoding="utf-8") as f: f.write(method + "\\n")

# Convert headers dict to curl args
args = []
for k, v in headers.items():
    args.append(f"-H \\\"{k}: {v}\\\"")
with open("upload_headers.txt", "w", encoding="utf-8") as f:
    f.write(" ".join(args) + "\\n")


# Optional S3 key
s3 = (data or {}).get("s3") or {}
with open("s3_key.txt", "w", encoding="utf-8") as f:
    f.write(s3.get("key",""))
PY
		
		METHOD="$(cat upload_method.txt)"
		
        HEADER_ARGS="$(cat upload_headers.txt)"
        UPLOAD_URL="$(cat upload_url.txt)"
        
        echo "Print HEADER_ARGS: ${HEADER_ARGS}"
		echo "Print UPLOAD_URL: ${UPLOAD_URL}"

                if [ -s s3_key.txt ]; then
                  echo "Target S3 key: $(cat s3_key.txt)"
                fi

                echo "Uploading ${LOG_FILE} using method ${METHOD}..."
                # Do NOT echo ${UPLOAD_URL}; it contains temporary credentials/signature
                curl -sS --fail --retry 3 --retry-delay 2 -X "${METHOD}" -H "Content-Type: text/plain" --upload-file "${LOG_FILE}" "${UPLOAD_URL}"
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
