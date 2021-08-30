from abc import abstractmethod
from PIL import Image
from io import BytesIO

import requests
import os
import logging
import boto3
from dotenv import load_dotenv

load_dotenv()

logger = logging.getLogger(__name__)


class Thumbnail:
    __slots__ = ('url', 'filename', 'SIZE', 'STATIC_DIR')

    def __init__(self, url, filename):
        self.url = url
        self.filename = filename
        self.SIZE = 128, 128
        self.STATIC_DIR = os.environ.get('STATIC_DIR', '/tmp/static')

    @abstractmethod
    def create(self):
        logger.info('Begin creation of thumbnail')
        content = requests.get(self.url).content
        with Image.open(BytesIO(content)) as img:
            img.thumbnail(self.SIZE)
            img.save(f'{self.STATIC_DIR}/{self.filename}', 'JPEG')
        logger.info('Finished creation of thumbnail')


class S3_Thumbnail(Thumbnail):
    __slots__ = ('s3_bucket')

    def create(self):
        logger.info('Begin creation of thumbnail in s3')
        content = requests.get(self.url).content
        with Image.open(BytesIO(content)) as img:
            in_memory_file = BytesIO()
            img.thumbnail(self.SIZE)
            img.save(in_memory_file, 'JPEG')
            in_memory_file.seek(0)

            s3 = boto3.client(
                's3', endpoint_url=os.environ.get("AWS_ENDPOINT", None))
            s3.upload_fileobj(
                in_memory_file,
                self.s3_bucket,
                f'thumbnail/{self.filename}',
                ExtraArgs={'ContentType': 'image/jpeg'}
            )
        logger.info('Finished creation of thumbnail in s3')
