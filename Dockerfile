# Stage 1
FROM maven:3.8.6-jdk-11 AS build

RUN git clone https://github.com/googleapis/managedkafka.git
WORKDIR managedkafka/kafka-java-auth

RUN sed -i 's/<version>3.7.0<\/version>/<version>3.7.1<\/version>/' pom.xml

RUN mvn validate
RUN mvn compile
RUN mvn package dependency:copy-dependencies

# Stage 2
FROM openjdk:11-jre-slim

# Set environment variables
ENV KAFKA_VERSION=3.7.1
ENV SCALA_VERSION=2.13
ENV KAFKA_HOME=/opt/kafka

# Download and extract Kafka binaries
RUN apt-get update && \
    apt-get install -y wget gnupg && \
    wget -qO - https://www.apache.org/dist/kafka/KEYS | apt-key add - && \
    wget https://downloads.apache.org/kafka/${KAFKA_VERSION}/kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    mkdir -p ${KAFKA_HOME} && \
    tar -xvf kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz -C ${KAFKA_HOME} --strip-components=1 && \
    rm kafka_${SCALA_VERSION}-${KAFKA_VERSION}.tgz && \
    apt-get purge -y wget gnupg && apt-get autoremove -y && apt-get clean

# Copy MirrorMaker2 configuration files
COPY connect-mirror-maker.properties ${KAFKA_HOME}/config/connect-mirror-maker.properties

# Copy the Maven configuration file (pom.xml)

WORKDIR ${KAFKA_HOME}/maven

#RUN mkdir ${KAFKA_HOME}/gcplibs

COPY --from=build managedkafka/kafka-java-auth/target/dependency/*.jar ${KAFKA_HOME}/libs/
COPY --from=build managedkafka/kafka-java-auth/target/*.jar ${KAFKA_HOME}/libs/

# Set working directory
WORKDIR ${KAFKA_HOME}

EXPOSE 8083
#ENV CLASSPATH="${CLASSPATH}:${KAFKA_HOME}/gcplibs

# Command to run MirrorMaker2
CMD ["bin/connect-mirror-maker.sh", "config/connect-mirror-maker.properties"]
