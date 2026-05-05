FROM docker.io/library/postgres:15

# Install pgvector extension
RUN apt-get update && \
    apt-get install -y postgresql-server-dev-15 make gcc && \
    git clone --branch v0.5.1 https://github.com/pgvector/pgvector.git && \
    cd pgvector && make && make install && \
    cd .. && rm -rf pgvector

# Set default database
ENV POSTGRES_DB=db1
