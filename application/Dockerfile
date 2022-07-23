FROM python:3.9-alpine AS base

WORKDIR /usr/src

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV CRYPTOGRAPHY_DONT_BUILD_RUST 1
ENV APPLICATION_PORT 8000

RUN set -eux && apk add --no-cache --virtual .build-deps \
    build-base libressl-dev libffi-dev gcc musl-dev python3-dev \
    libressl-dev libffi-dev gcc musl-dev python3-dev \
    tiff-dev jpeg-dev openjpeg-dev zlib-dev freetype-dev lcms2-dev \
    libwebp-dev tcl-dev tk-dev harfbuzz-dev fribidi-dev libimagequant-dev \
    libxcb-dev libpng-dev \
    && pip install --upgrade pip setuptools wheel \
    && rm -rf /root/.cache/pip

COPY ./requirements.txt /usr/src/requirements.txt
RUN pip install -r /usr/src/requirements.txt