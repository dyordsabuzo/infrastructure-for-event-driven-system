from unittest import TestCase
from pathlib import Path
from workers import thumbnail

from moto import mock_s3

import boto3


class TestWorkers(TestCase):
    def test_thumbnail(self):
        url = 'http://personal.psu.edu/xqz5228/jpg.jpg'
        filename = 'somefilename'
        thumbnail.create(url, filename)
        path = Path(f'/tmp/static/{filename}')
        self.assertTrue(path.is_file())

    def test_s3_thumbnail(self):
        with mock_s3():
            bucket_name = "somebucket"
            s3 = boto3.client('s3')
            s3.create_bucket(Bucket=bucket_name)

            url = 'http://personal.psu.edu/xqz5228/jpg.jpg'
            filename = 'somefilename'
            thumbnail.create_s3_thumbnail(url, filename, bucket_name)
            response = s3.list_objects_v2(Bucket=bucket_name)
            self.assertTrue(
                response['Contents'][0]['Key'],
                f'thumbnail/{filename}'
            )
