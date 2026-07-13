FROM --platform=$BUILDPLATFORM postgres:16-alpine

WORKDIR /schema-loader
COPY schema.sql /schema-loader/schema.sql
COPY entrypoint.sh /schema-loader/entrypoint.sh
RUN chmod +x /schema-loader/entrypoint.sh

ENTRYPOINT ["/schema-loader/entrypoint.sh"]
