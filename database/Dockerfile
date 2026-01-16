FROM postgres:15-alpine

# Copy initialization script
COPY init.sql /docker-entrypoint-initdb.d/

# Set default environment variables
ENV POSTGRES_DB=inventory_db
ENV POSTGRES_USER=postgres

# Expose PostgreSQL port
EXPOSE 5432

# The postgres image already has the correct entrypoint
# It will automatically run scripts in /docker-entrypoint-initdb.d/
