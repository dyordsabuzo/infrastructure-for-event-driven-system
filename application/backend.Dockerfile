FROM python:3.9-alpine AS base

WORKDIR /usr/src

ENV PYTHONDONTWRITEBYTECODE 1
ENV PYTHONUNBUFFERED 1
ENV CRYPTOGRAPHY_DONT_BUILD_RUST 1
ENV APPLICATION_PORT 8000

COPY ./backend.requirements.txt /usr/src/requirements.txt

RUN set -eux \
    && apk add --no-cache --virtual .build-deps build-base \
    libressl-dev libffi-dev gcc musl-dev python3-dev \
    libressl-dev libffi-dev gcc musl-dev python3-dev \
    tiff-dev jpeg-dev openjpeg-dev zlib-dev freetype-dev lcms2-dev \
    libwebp-dev tcl-dev tk-dev harfbuzz-dev fribidi-dev libimagequant-dev \
    libxcb-dev libpng-dev \
    && pip install --upgrade pip setuptools wheel \
    && pip install -r /usr/src/requirements.txt \
    && rm -rf /root/.cache/pip

COPY ./app/ /usr/src/app/
COPY ./templates/ /usr/src/templates/
COPY ./workers/ /usr/src/workers/
COPY ./entities/ /usr/src/entities/

FROM base AS test

COPY ./tests/backend/ /usr/src/tests/
RUN pytest
RUN touch /usr/src/test.complete

FROM base AS final
COPY --from=test /usr/src/test.complete .
COPY ./backend.entrypoint.sh /usr/src/entrypoint.sh

# RUN addgroup -S appgroup && adduser -S appuser -G appgroup
# USER appuser

ENTRYPOINT [ "sh", "/usr/src/entrypoint.sh" ]