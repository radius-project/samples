FROM python:3.14-alpine
COPY ./src/requirements.txt /app/requirements.txt
WORKDIR /app
RUN python3 -m pip install --upgrade --ignore-installed pip setuptools wheel \
    && python3 -m pip install --no-cache-dir -r requirements.txt
COPY ./src /app
ENTRYPOINT [ "python3" ]
CMD [ "app.py" ]
