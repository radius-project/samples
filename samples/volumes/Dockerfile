FROM alpine:3.14
RUN apk add --no-cache python3 py3-pip
COPY ./src/requirements.txt /app/requirements.txt
WORKDIR /app
RUN pip install -r requirements.txt
COPY ./src /app
ENTRYPOINT [ "python3" ]
CMD [ "app.py" ]
