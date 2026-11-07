pipeline {
    agent {
        kubernetes {
            defaultContainer 'jnlp'
            yaml '''
apiVersion: v1
kind: Pod
spec:
  serviceAccountName: jenkins-sa
  volumes:
    - name: docker-config
      emptyDir: {}
  containers:
    - name: aws
      image: amazon/aws-cli:2
      command: ["sh", "-c", "cat"]
      tty: true
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
    - name: kaniko
      image: gcr.io/kaniko-project/executor:v1.23.2-debug
      command: ["/busybox/cat"]
      tty: true
      volumeMounts:
        - name: docker-config
          mountPath: /kaniko/.docker
'''
        }
    }

    environment {
        AWS_REGION = 'us-west-2'
        ECR_REGISTRY = '516885649085.dkr.ecr.us-west-2.amazonaws.com'
        ECR_REPOSITORY = 'lesson-5-ecr'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
                script {
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}-${env.GIT_COMMIT.take(7)}"
                }
            }
        }

        stage('Build and push image to ECR') {
            when {
                anyOf {
                    changeset 'docker/django/**'
                    changeset 'Jenkinsfile'
                }
            }
            steps {
                container('aws') {
                    sh '''
                        set +x
                        TOKEN=$(aws ecr get-login-password --region "$AWS_REGION")
                        AUTH=$(printf 'AWS:%s' "$TOKEN" | base64 | tr -d '\\n')
                        printf '{"auths":{"%s":{"auth":"%s"}}}\\n' \
                          "$ECR_REGISTRY" "$AUTH" > /kaniko/.docker/config.json
                        unset TOKEN AUTH
                    '''
                }

                container('kaniko') {
                    sh '''
                        /kaniko/executor \
                          --context="dir://${WORKSPACE}/docker/django" \
                          --dockerfile="${WORKSPACE}/docker/django/Dockerfile" \
                          --destination="${ECR_REGISTRY}/${ECR_REPOSITORY}:${IMAGE_TAG}"
                    '''
                }
            }
        }

        stage('Update Helm chart in Git') {
            when {
                anyOf {
                    changeset 'docker/django/**'
                    changeset 'Jenkinsfile'
                }
            }
            steps {
                sh '''
                    sed -i "s/tag: .*/tag: ${IMAGE_TAG}/" \
                      lesson-9/charts/django-app/values.yaml

                    git config user.name "Jenkins"
                    git config user.email "jenkins@users.noreply.github.com"
                    git add lesson-9/charts/django-app/values.yaml
                    git commit -m "Update Django image to ${IMAGE_TAG}"
                '''

                withCredentials([gitUsernamePassword(
                    credentialsId: 'github-token',
                    gitToolName: 'Default'
                )]) {
                    sh 'git push origin HEAD:lesson-9'
                }
            }
        }
    }
}