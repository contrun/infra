FROM apache/superset
# Switching to root to install the required packages
USER root
RUN pip install mysqlclient psycopg2-binary redis
USER superset
