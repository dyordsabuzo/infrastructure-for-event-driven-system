#!/bin/sh
celery -A workers.thumbnail worker --loglevel=info