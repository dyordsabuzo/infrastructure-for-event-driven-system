from unittest import TestCase, mock
from workers.config import get_celery_app
from moto import mock_sqs

import os
import boto3


class TestCeleryConfig(TestCase):
    def test_config(self):
        default = get_celery_app()
        self.assertIsNotNone(default.conf.broker_url)
        self.assertIsNotNone(default.conf.result_backend)
        self.assertTrue('amqp' in default.conf.broker_url)

        with mock.patch.dict(os.environ, {
            "BROKER_TYPE": "sqs",
            "AWS_ACCESS_KEY_ID": "temp",
            "AWS_SECRET_ACCESS_KEY": "temp",
            "AWS_DEFAULT_REGION": "ap-southeast-2",
            "QUEUE_NAME": "test"
        }):
            with mock_sqs():
                queue_name = "test"
                sqs_client = boto3.client('sqs')
                sqs_client.create_queue(QueueName=queue_name)

                sqs = get_celery_app()
                self.assertIsNotNone(sqs.conf.broker_url)
                self.assertTrue('sqs' in sqs.conf.broker_url)
                self.assertEqual(
                    sqs_client.get_queue_url(QueueName=queue_name)['QueueUrl'],
                    sqs.conf.broker_transport_options['predefined_queues']['celery']['url']
                )

        with mock.patch.dict(os.environ, {
            "BROKER_TYPE": "sqs",
            "AWS_ACCESS_KEY_ID": "temp",
            "AWS_SECRET_ACCESS_KEY": "temp",
            "AWS_DEFAULT_REGION": "ap-southeast-2",
            "QUEUE_NAME": "test",
            "SQS_CHECK_DURATION": "5"
        }):
            with mock_sqs():
                with self.assertRaises(Exception):
                    sqs = get_celery_app()
