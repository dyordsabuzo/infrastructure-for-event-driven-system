FROM python:3.9-alpine AS base

WORKDIR /usr/src

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONBUFFERED 1
ENV CRYPTOGRAPHY_DONT_BUILD_RUST 1
ENV PYCURL_VERSION=7_44_1

COPY ./worker.requirements.txt requirements.txt
RUN set -eux \
    && apk add --no-cache --virtual .build-deps build-base \
    libressl-dev libffi-dev gcc musl-dev python3-dev \
    tiff-dev jpeg-dev openjpeg-dev zlib-dev freetype-dev lcms2-dev \
    libwebp-dev tcl-dev tk-dev harfbuzz-dev fribidi-dev libimagequant-dev \
    libxcb-dev libpng-dev openssl-dev curl-dev wget

RUN wget https://github.com/pycurl/pycurl/archive/refs/tags/REL_${PYCURL_VERSION}.tar.gz && \
    tar -zxf REL_${PYCURL_VERSION}.tar.gz && \
    cd pycurl-REL_${PYCURL_VERSION} && \
    python setup.py install && \
    cd .. && rm -rf *REL_${PYCURL_VERSION}*

RUN pip install --upgrade pip setuptools wheel \
    && pip install -r /usr/src/requirements.txt \
    && rm -rf /root/.cache/pip

COPY ./entities/ /usr/src/entities/
COPY ./workers/ /usr/src/workers/

FROM base AS test

COPY ./tests/worker/ /usr/src/tests/
RUN pytest
RUN touch /usr/src/test.complete

FROM base AS final
COPY --from=test /usr/src/test.complete .
COPY ./worker.entrypoint.sh /usr/src/entrypoint.sh

# RUN addgroup -S appgroup && adduser -S appuser -G appgroup
# USER appuser

ENTRYPOINT [ "sh", "/usr/src/entrypoint.sh" ]