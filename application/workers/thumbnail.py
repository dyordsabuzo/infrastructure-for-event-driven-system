from .config import get_celery_app
from entities.thumbnail import S3_Thumbnail, Thumbnail

app = get_celery_app()


@app.task(bind=True, name='create_thumbnail')
def create(self, url, filename):
    thumbnail = Thumbnail(url, filename)
    thumbnail.create()


@app.task(bind=True, name='create_s3_thumbnail')
def create_s3_thumbnail(self, url, filename, bucket_name):
    thumbnail = S3_Thumbnail(url, filename)
    thumbnail.s3_bucket = bucket_name
    thumbnail.create()
