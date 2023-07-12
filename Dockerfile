# vim:set ft=dockerfile:
#
# Based on official postgres and cloudnative-pg containers 
#
FROM --platform=${BUILDPLATFORM:-linux/amd64} postgres:15.3 as build
ARG BUILDPLATFORM

RUN apt-get update && apt-get -y install \
  git make gcc \
  postgresql-server-dev-15 \
  librdkafka-dev \
  zlib1g-dev && \
  git clone https://github.com/adjust/kafka_fdw.git

RUN cd kafka_fdw && make && make install

FROM --platform=${BUILDPLATFORM:-linux/amd64} postgres:15.3

ARG BUILDPLATFORM

# Do not split the description, otherwise we will see a blank space in the labels
LABEL name="PostgreSQL Container Images with Kafka FWD" \
      vendor="Digitalis.IO" \
      version="${PG_VERSION}" \
      summary="PostgreSQL Container images." \
      description="This Docker image contains PostgreSQL and Barman Cloud based on Postgres 15.3."

LABEL org.opencontainers.image.description="This Docker image contains PostgreSQL and Barman Cloud based on Postgres 15.3-debian."

COPY requirements.txt /

# Install additional extensions
RUN set -xe; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		"postgresql-${PG_MAJOR}-pgaudit" \
		"postgresql-${PG_MAJOR}-pg-failover-slots" \
	; \
	rm -fr /tmp/* ; \
	rm -rf /var/lib/apt/lists/*;

# Install barman-cloud
RUN set -xe; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		python3-pip \
		python3-psycopg2 \
		python3-setuptools \
	; \
	pip3 install --upgrade pip; \
# TODO: Remove --no-deps once https://github.com/pypa/pip/issues/9644 is solved
	pip3 install --no-deps -r requirements.txt; \
	rm -rf /var/lib/apt/lists/*;

COPY --from=build /usr/lib/postgresql/15/lib/bitcode/kafka_fdw /usr/lib/postgresql/15/lib/bitcode/kafka_fdw
COPY --from=build /usr/share/postgresql/15/extension/kafka* /usr/share/postgresql/15/extension/
COPY --from=build /usr/lib/postgresql/15/lib/kafka_fdw.so /usr/lib/postgresql/15/lib/kafka_fdw.so

# Change the uid of postgres to 26
RUN usermod -u 26 postgres
USER 26
