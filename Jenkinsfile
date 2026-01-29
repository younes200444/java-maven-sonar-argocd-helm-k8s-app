pipeline {
	// -------------------------------------------------------------------------
	// 1. CONFIGURATION DE L'AGENT (L'ENVIRONNEMENT D'EXÉCUTION)
	// -------------------------------------------------------------------------
	agent {
		docker {
			// On utilise une image qui contient déjà Java et Maven (notre "Boîte à outils")
			image 'younes015/maven-jenkins-agent:v1'

			// IMPORTANT : On monte le socket Docker de l'hôte vers le conteneur.
			// Cela permet au conteneur d'ordonner à la machine hôte de construire des images Docker.
			// C'est la technique "Docker-outside-of-Docker" (DooD).
			args '--user root -v /var/run/docker.sock:/var/run/docker.sock'
		}
	}

	// -------------------------------------------------------------------------
	// 2. VARIABLES D'ENVIRONNEMENT GLOBALES
	// -------------------------------------------------------------------------
	environment {
		// Le nom de l'image Docker sera dynamique (ex: mon-image:42, mon-image:43...)
		DOCKER_IMAGE = "younes015/ultimate-cicd:${BUILD_NUMBER}"

		GIT_REPO_NAME = "java-maven-sonar-argocd-helm-k8s-app"
		GIT_USER_NAME = "younes200444"

		// Note : La variable SONAR_URL doit être définie dans la configuration globale de Jenkins
	}

	stages {

		// ----------------------------------------------------------------------
		// ÉTAPE 1 : RÉCUPÉRATION DU CODE SOURCE
		// ----------------------------------------------------------------------
		stage('checkout') {
			steps {
				// Récupère la branche 'main' du dépôt GitHub
				git branch: 'main', url: "https://github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}"
			}
		}

		// ----------------------------------------------------------------------
		// ÉTAPE 2 : COMPILATION ET TESTS UNITAIRES
		// ----------------------------------------------------------------------
		stage('build and test') {
			steps {
				// Compile le code Java et crée le fichier .jar
				// 'clean' supprime les anciens fichiers de build
				// 'package' lance les tests et empaquette l'application
				sh 'mvn clean package'
			}
		}

		// ----------------------------------------------------------------------
		// ÉTAPE 3 : ANALYSE DE LA QUALITÉ DU CODE (SONARQUBE)
		// ----------------------------------------------------------------------
		stage('analyse SonarQube') {
			steps {
				// Récupère le token secret de Jenkins (ID: sonarqube) de manière sécurisée
				withCredentials([string(credentialsId : 'sonarqube', variable : 'SONAR_AUTH_TOKEN')]) {
					// Envoie le rapport d'analyse au serveur SonarQube
					sh "mvn sonar:sonar -Dsonar.login=${SONAR_AUTH_TOKEN} -Dsonar.host.url=${env.SONAR_URL}"
				}
			}
		}

		// ----------------------------------------------------------------------
		// ÉTAPE 4 : CONSTRUCTION ET ENVOI DE L'IMAGE DOCKER
		// ----------------------------------------------------------------------
		stage('build image docker') {
			steps {
				// Construit l'image en utilisant le Dockerfile présent à la racine (.)
				sh "docker build -t ${DOCKER_IMAGE} ."

				// Se connecte au Docker Hub (ID credentials: docker-cred) et pousse l'image
				docker.withRegistry('https://index.docker.io/v1/', "docker-cred"){
					docker.image("${DOCKER_IMAGE}").push()
				}
			}
		}

		// ----------------------------------------------------------------------
		// ÉTAPE 5 : GITOPS - MISE À JOUR DU MANIFESTE KUBERNETES
		// ----------------------------------------------------------------------
		stage('update manifeste K8S') {
			// OPTIMISATION : On sort du conteneur Maven.
			// Cette étape n'a besoin que de 'git' et 'sed', donc on utilise l'agent léger par défaut.
			agent none

			steps {
				// Récupère le Token GitHub personnel pour avoir le droit d'écrire (push)
				withCredentials([string(credentialsId : 'github', variable : 'GIT_TOKEN')]) {
					sh """
                # Arrête le script immédiatement si une commande échoue
                set -e

                # 1. Préparation d'un dossier temporaire propre
                REPO_DIR="\$WORKSPACE/temp-git-repo"
                rm -rf "\$REPO_DIR"
                mkdir -p "\$REPO_DIR"

                # 2. Clonage du dépôt contenant les configurations K8s
                git clone https://github.com/${GIT_USER_NAME}/${GIT_REPO_NAME} "\$REPO_DIR"
                cd "\$REPO_DIR"

                # 3. Configuration de l'identité Git (nécessaire pour le commit)
                git config user.email "youneselamrani015@gmail.com"
                git config user.name "younes200444"

                # 4. Modification dynamique du fichier YAML
                # La commande 'sed' cherche l'ancienne version de l'image (peu importe laquelle grâce à .*)
                # et la remplace par la nouvelle version : ${BUILD_NUMBER}
                sed -i "s#image: younes015/ultimate-cicd:.*#image: younes015/ultimate-cicd:${BUILD_NUMBER}#" \
                spring-boot-app-manifests/deployment.yml

                # 5. Commit et Push des changements vers GitHub
                git add spring-boot-app-manifests/deployment.yml
                git commit -m "deployment:${BUILD_NUMBER}"

                # Utilisation du Token sécurisé pour s'authentifier
                git push https://${GIT_TOKEN}@github.com/${GIT_USER_NAME}/${GIT_REPO_NAME}.git HEAD:main

                echo "Push réussi ! ArgoCD va détecter ce changement et déployer la v${BUILD_NUMBER}"
             """
				}
			}
		}
	}

	// -------------------------------------------------------------------------
	// NOTIFICATIONS (À LA FIN DU PIPELINE)
	// -------------------------------------------------------------------------
	post {
		// Si tout s'est bien passé
		success {
			slackSend(
				channel: '#test-jenkins',
				color: '#36a64f', // Vert
				message: "🎉 SUCCESS — Build #${BUILD_NUMBER} déployé avec succès ! 🚀"
			)
		}

		// Si une étape a échoué
		failure {
			slackSend(
				channel: '#test-jenkins',
				color: '#ff0000', // Rouge
				message: "❌ FAILURE — Le pipeline #${BUILD_NUMBER} a échoué ! ⚠️"
			)
		}
	}
}