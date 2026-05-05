// ╔══════════════════════════════════════════════════════════════════════════╗
// ║          JENKINSFILE — Usine Logicielle DevOps Complète                 ║
// ║  Exercice 1 : CI + SonarQube Quality Gate                               ║
// ║  Exercice 2 : Docker Build + Trivy Scan + Docker Push                   ║
// ║  Exercice 3 : Terraform IaC + Ansible/K8s Deploy + Smoke Test           ║
// ╚══════════════════════════════════════════════════════════════════════════╝

pipeline {
    agent any

    // ── Variables globales ─────────────────────────────────────────────────
    environment {
        // Docker Hub
        DOCKERHUB_USER   = 'marambr'           // ← à adapter
        IMAGE_NAME       = "${DOCKERHUB_USER}/flask-devops-app"
        IMAGE_TAG        = "${BUILD_NUMBER}"
        IMAGE_FULL       = "${IMAGE_NAME}:${IMAGE_TAG}"

        // SonarQube (nom du serveur configuré dans Jenkins → Manage Jenkins)
        SONAR_SERVER     = 'SonarQubeServer'

        // Credentials Jenkins (à créer dans Manage Jenkins → Credentials)
        DOCKERHUB_CREDS  = 'dockerhub-credentials'
        KUBECONFIG_CREDS = 'kubeconfig-k8s'
        SONAR_TOKEN_CREDS= 'sonarqube-token'

        // Kubernetes / Application
        K8S_NAMESPACE    = 'devops-tp'
        APP_URL          = 'http://flask-devops-app.local'  // ← adapter selon Ingress

        // Terraform
        TF_DIR           = 'terraform'
        TF_WORKSPACE     = 'production'
    }

    // ── Options globales ───────────────────────────────────────────────────
    options {
        buildDiscarder(logRotator(numToKeepStr: '10'))
        timestamps()
        timeout(time: 45, unit: 'MINUTES')
        disableConcurrentBuilds()
    }

    stages {

        // ══════════════════════════════════════════════════════════════════
        //  EXERCICE 1 — Continuous Integration & Qualité du Code
        // ══════════════════════════════════════════════════════════════════

        stage('📥 Checkout') {
            steps {
                echo "==> Récupération du code source depuis Git..."
                checkout scm
                sh 'git log --oneline -5'
            }
        }

        stage('📦 Install Dependencies') {
            steps {
                echo "==> Installation des dépendances Python..."
                sh '''
                    python3 -m venv venv
                    . venv/bin/activate
                    pip install --upgrade pip
                    pip install -r app/requirements.txt
                '''
            }
        }

        stage('🧪 Unit Tests') {
            steps {
                echo "==> Exécution des tests unitaires avec pytest..."
                sh '''
                    . venv/bin/activate
                    cd app
                    pytest test_app.py \
                        --junitxml=../reports/junit.xml \
                        --cov=. \
                        --cov-report=xml:../reports/coverage.xml \
                        --cov-report=html:../reports/htmlcov \
                        -v
                '''
            }
            post {
                always {
                    // Publie les résultats de tests dans Jenkins
                    junit 'reports/junit.xml'
                    publishHTML(target: [
                        allowMissing: false,
                        alwaysLinkToLastBuild: true,
                        keepAll: true,
                        reportDir: 'reports/htmlcov',
                        reportFiles: 'index.html',
                        reportName: 'Coverage Report'
                    ])
                }
            }
        }

        stage('🔍 SonarQube Analysis') {
            steps {
                echo "==> Analyse statique du code avec SonarQube..."
                withSonarQubeEnv(SONAR_SERVER) {
                    withCredentials([string(credentialsId: SONAR_TOKEN_CREDS, variable: 'SONAR_AUTH_TOKEN')]) {
                        sh """
                            sonar-scanner \
                                -Dsonar.projectKey=flask-devops-app \
                                -Dsonar.sources=app \
                                -Dsonar.tests=app \
                                -Dsonar.test.inclusions=**/test_*.py \
                                -Dsonar.python.coverage.reportPaths=reports/coverage.xml \
                                -Dsonar.login=${SONAR_AUTH_TOKEN} \
                                -Dsonar.host.url=${SONAR_HOST_URL}
                        """
                    }
                }
            }
        }

        stage('✅ Quality Gate') {
            steps {
                echo "==> Vérification du Quality Gate SonarQube..."
                // Attend le résultat du Quality Gate (timeout 5 min)
                timeout(time: 5, unit: 'MINUTES') {
                    waitForQualityGate abortPipeline: true
                }
            }
        }

        // ══════════════════════════════════════════════════════════════════
        //  EXERCICE 2 — Livraison Continue : Docker + Trivy + Push
        // ══════════════════════════════════════════════════════════════════

       /* stage('🐳 Docker Build') {
            steps {
                echo "==> Construction de l'image Docker : ${IMAGE_FULL}"
                sh """
                    docker build \
                        --no-cache \
                        --label "build.number=${BUILD_NUMBER}" \
                        --label "git.commit=\$(git rev-parse --short HEAD)" \
                        -t ${IMAGE_FULL} \
                        -t ${IMAGE_NAME}:latest \
                        .
                """
                sh "docker images | grep ${IMAGE_NAME}"
            }
        }

        stage('🛡️ Security Scan (Trivy)') {
            steps {
                echo "==> Scan de vulnérabilités avec Trivy sur ${IMAGE_FULL}..."
                sh """
                    # Trivy doit être installé sur l'agent Jenkins
                    # Installation : https://github.com/aquasecurity/trivy

                    trivy image \
                        --exit-code 0 \
                        --severity LOW,MEDIUM \
                        --format table \
                        ${IMAGE_FULL}

                    # Echec du pipeline si vulnérabilités CRITICAL ou HIGH détectées
                    trivy image \
                        --exit-code 1 \
                        --severity HIGH,CRITICAL \
                        --format json \
                        --output reports/trivy-report.json \
                        ${IMAGE_FULL}
                """
            }
            post {
                always {
                    // Archive le rapport Trivy
                    archiveArtifacts artifacts: 'reports/trivy-report.json',
                                     allowEmptyArchive: true
                }
            }
        }

        stage('📤 Docker Push') {
            steps {
                echo "==> Publication de l'image sur Docker Hub..."
                withCredentials([usernamePassword(
                    credentialsId: DOCKERHUB_CREDS,
                    usernameVariable: 'DH_USER',
                    passwordVariable: 'DH_PASS'
                )]) {
                    sh """
                        echo "${DH_PASS}" | docker login -u "${DH_USER}" --password-stdin
                        docker push ${IMAGE_FULL}
                        docker push ${IMAGE_NAME}:latest
                        docker logout
                    """
                }
                echo "✅ Image publiée : ${IMAGE_FULL}"
            }
        }

        // ══════════════════════════════════════════════════════════════════
        //  EXERCICE 3 — Déploiement IaC : Terraform + Ansible + K8s
        // ══════════════════════════════════════════════════════════════════

        stage('🏗️ Terraform Init & Plan') {
            steps {
                echo "==> Provisionnement de l'infrastructure avec Terraform..."
                dir(TF_DIR) {
                    sh """
                        terraform init -input=false
                        terraform workspace select ${TF_WORKSPACE} || \
                            terraform workspace new ${TF_WORKSPACE}
                        terraform plan \
                            -var="image_tag=${IMAGE_TAG}" \
                            -out=tfplan \
                            -input=false
                    """
                }
            }
        }

        stage('🏗️ Terraform Apply') {
            // Approbation manuelle avant d'appliquer en production
            input {
                message "Appliquer le plan Terraform ?"
                ok "Oui, provisionner"
            }
            steps {
                dir(TF_DIR) {
                    sh 'terraform apply -input=false -auto-approve tfplan'
                    // Récupère l'output Terraform (ex: kubeconfig, IP...)
                    sh 'terraform output -json > ../reports/terraform-outputs.json'
                }
            }
            post {
                always {
                    archiveArtifacts artifacts: 'reports/terraform-outputs.json',
                                     allowEmptyArchive: true
                }
            }
        }

        stage('⚙️ Ansible — Configure & Deploy') {
            steps {
                echo "==> Configuration K8s et déploiement via Ansible..."
                withCredentials([file(
                    credentialsId: KUBECONFIG_CREDS,
                    variable: 'KUBECONFIG_FILE'
                )]) {
                    sh """
                        export KUBECONFIG=${KUBECONFIG_FILE}

                        ansible-playbook ansible/playbook-deploy.yml \
                            -e image_tag=${IMAGE_TAG} \
                            -e image_name=${IMAGE_NAME} \
                            -e k8s_namespace=${K8S_NAMESPACE} \
                            -e kubeconfig=${KUBECONFIG_FILE} \
                            -v
                    """
                }
            }
        }

        stage('🔬 Smoke Test') {
            steps {
                echo "==> Vérification de l'accessibilité de l'application..."
                sh """
                    # Attendre que le déploiement soit prêt (max 3 min)
                    kubectl rollout status deployment/flask-devops-app \
                        -n ${K8S_NAMESPACE} \
                        --timeout=3m

                    # Test HTTP de l'endpoint de santé
                    for i in 1 2 3 4 5; do
                        HTTP_CODE=\$(curl -s -o /dev/null -w '%{http_code}' ${APP_URL}/health)
                        echo "Tentative \$i — HTTP Status: \$HTTP_CODE"
                        if [ "\$HTTP_CODE" = "200" ]; then
                            echo "✅ Smoke Test réussi ! Application accessible."
                            exit 0
                        fi
                        sleep 10
                    done

                    echo "❌ Smoke Test échoué après 5 tentatives."
                    exit 1
                """
            }
        }
    }

    // ── Post-pipeline ──────────────────────────────────────────────────────
    post {
        success {
            echo """
            ╔════════════════════════════════════════╗
            ║  ✅  PIPELINE TERMINÉ AVEC SUCCÈS      ║
            ║  Image : ${IMAGE_FULL}
            ║  App   : ${APP_URL}
            ╚════════════════════════════════════════╝
            """
        }
        failure {
            echo "❌ Pipeline échoué — Vérifiez les logs ci-dessus."
            // Nettoyage de l'image locale en cas d'échec
            sh "docker rmi ${IMAGE_FULL} || true"
        }
        always {
            // Nettoyage du workspace Jenkins
            cleanWs(cleanWhenSuccess: false)
        }*/
    }
}
