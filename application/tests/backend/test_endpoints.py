import os
from fastapi.exceptions import HTTPException
from fastapi.testclient import TestClient
from unittest import TestCase, mock
from app.main import app, create_thumbnail, Thumbnail


client = TestClient(app)


class TestEndpoints(TestCase):
    @mock.patch('workers.thumbnail.create_s3_thumbnail.delay')
    def test_backend_main(self, mock_worker):
        tn = Thumbnail(
            url='http://lorempixel.com/400/200/',
            filename='filefromtestbackendmain'
        )
        self.assertEqual(create_thumbnail(tn), tn)
        mock_worker.assert_called()

    @mock.patch('workers.thumbnail.create_s3_thumbnail.delay')
    def test_create_thumbnail(self, mock_worker):
        source_url = "https://jpeg.org/images/jpeg-home.jpg"
        response = client.post('/thumbnail', json={"url": source_url})
        self.assertEqual(response.status_code, 200)
        self.assertIsNotNone(response.json())

        output = response.json()
        self.assertEqual(output["url"], source_url)
        self.assertIsNotNone(output["filename"])

    def test_create_thumbnail_exceptions(self):
        sourceurl = "some url"
        tn = Thumbnail(
            url="some url",
            filename="http://lorempixel.com/400/200/"
        )
        self.assertRaises(HTTPException,
                          create_thumbnail,
                          tn
                          )

        sourceurl = "https://www.google.com"
        response = client.post('/thumbnail',  json={"url": sourceurl})
        self.assertEqual(response.status_code, 500)

    @mock.patch.dict(os.environ, {
        "THUMBNAIL_BASE_URL": "https://jpeg.org/images"
    })
    def test_load_thumbnail(self):
        filename = "jpeg-home.jpg"
        response = client.get(f'/thumbnail/{filename}', json={})
        self.assertEqual(response.status_code, 200)
        self.assertTrue(
            f'{os.environ.get("THUMBNAIL_BASE_URL")}/{filename}' in response.content.decode('utf-8')
        )

        filename = "Rainbow_on_Mountain_HD_ImageTESTSSSSSSS.jpg"
        response = client.get(f'/thumbnail/{filename}', json={})
        self.assertEqual(response.status_code, 404)
