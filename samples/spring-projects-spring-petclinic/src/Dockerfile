ARG PETCLINIC_COMMIT=51045d1648dad955df586150c1a1a6e22ef400c2

FROM --platform=$BUILDPLATFORM eclipse-temurin:17-jdk-jammy AS build
ARG PETCLINIC_COMMIT
WORKDIR /workspace
RUN apt-get update \
    && apt-get install -y --no-install-recommends git ca-certificates \
    && rm -rf /var/lib/apt/lists/*
RUN git clone https://github.com/spring-projects/spring-petclinic.git . \
    && git checkout "${PETCLINIC_COMMIT}"
RUN ./mvnw -B -DskipTests clean package \
    && cp target/*.jar app.jar

FROM eclipse-temurin:17-jre-jammy AS runtime
WORKDIR /app
RUN groupadd --system spring && useradd --system --gid spring spring
COPY --from=build --chown=spring:spring /workspace/app.jar /app/app.jar
USER spring
EXPOSE 8080
ENTRYPOINT ["java", "-jar", "/app/app.jar"]
