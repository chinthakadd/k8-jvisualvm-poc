FROM openjdk:8-jdk-alpine
EXPOSE 8080
ADD /build/libs/k8-jvisualvm-poc-0.0.1-SNAPSHOT.jar k8-jvisualvm-poc.jar
ENTRYPOINT ["java", "-jar", "k8-jvisualvm-poc.jar"]