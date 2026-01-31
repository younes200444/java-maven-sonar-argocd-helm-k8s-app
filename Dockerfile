
FROM eclipse-temurin:17-jre-alpine

# 2. Argument pour trouver le jar
ARG artifact=target/*.jar

# 3. Création du dossier de travail
WORKDIR /opt/app

# 4. Copie de l'application
COPY ${artifact} app.jar

# Cela empêche un pirate de prendre le contrôle total du conteneur
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# 6. Démarrage
ENTRYPOINT ["java", "--add-opens", "java.base/java.lang=ALL-UNNAMED", "--add-opens", "java.base/java.io=ALL-UNNAMED", "--add-opens", "java.base/java.util=ALL-UNNAMED", "--add-opens", "java.base/java.util.concurrent=ALL-UNNAMED", "-jar", "app.jar"]