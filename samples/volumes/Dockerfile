FROM alpine:3.14
RUN apk add --no-cache python3 py3-pip
COPY ./src/requirements.txt /app/requirements.txt
WORKDIR /app
RUN python3 -m pip install --upgrade pip setuptools wheel \
    && python3 -m pip install --no-cache-dir -r requirements.txt
COPY ./src /app
ENTRYPOINT [ "python3" ]
CMD [ "app.py" ]
