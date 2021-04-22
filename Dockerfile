FROM python:3.8.6-slim-buster
USER root
RUN apt-get update && apt-get upgrade -y \
    && apt-get install -qqy \
        bash \
        build-essential \
        curl \
        nano
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] http://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list && curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg  add - && apt-get update -y && apt-get install google-cloud-sdk -y
COPY requirements.txt /app/requirements.txt
WORKDIR /app/
RUN pip3 install -r requirements.txt
COPY ./src /app/src
WORKDIR /app/src

RUN pip install Flask gunicorn

ENV PORT 8080
CMD exec gunicorn --bind 0.0.0.0:$PORT --workers 1 --threads 8 --timeout 0 main:app
