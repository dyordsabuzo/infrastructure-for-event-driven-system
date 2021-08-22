from unittest import TestCase
from pathlib import Path

from PIL import UnidentifiedImageError
from requests.models import MissingSchema
from entities.thumbnail import Thumbnail, S3_Thumbnail

from moto import mock_s3

import pytest
import boto3


class TestEntities(TestCase):
    def test_entities(self):
        url = 'http://personal.psu.edu/xqz5228/jpg.jpg'
        filename = 'somefilename'
        thumbnail = Thumbnail(url, filename)
        self.assertEqual(thumbnail.url, url)
        self.assertEqual(thumbnail.filename, filename)

        thumbnail.create()
        path = Path(f'/tmp/static/{filename}')
        self.assertTrue(path.is_file())

    def test_s3_entities(self):
        with mock_s3():
            bucket_name = "somebucket"
            s3 = boto3.client('s3')
            s3.create_bucket(Bucket=bucket_name)

            url = 'http://personal.psu.edu/xqz5228/jpg.jpg'
            filename = 'somefilename'
            thumbnail = S3_Thumbnail(url, filename)
            thumbnail.s3_bucket = bucket_name
            self.assertEqual(thumbnail.url, url)
            self.assertEqual(thumbnail.filename, filename)

            thumbnail.create()
            response = s3.list_objects_v2(Bucket=bucket_name)
            self.assertTrue(
                response['Contents'][0]['Key'],
                f'thumbnail/{filename}'
            )

    def test_thumbnail_exceptions(self):
        with pytest.raises(UnidentifiedImageError):
            url = 'https://www.google.com'
            thumbnail = Thumbnail(url, 'somefile')
            thumbnail.create()

        with pytest.raises(MissingSchema):
            url = 'someurl'
            thumbnail = Thumbnail(url, 'somefile')
            thumbnail.create()
