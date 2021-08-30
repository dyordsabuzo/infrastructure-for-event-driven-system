from abc import abstractmethod
from celery import Celery
from botocore.exceptions import ClientError

import os
import time
import boto3
from dotenv import load_dotenv

load_dotenv()


class CeleryDefaultConfig:

    @abstractmethod
    def get_config(self):
        return {
            'broker_url': os.environ.get('BROKER', 'amqp://rabbitmq:5673//'),
            'result_backend': os.environ.get('BACKEND', 'amqp://rabbitmq:5673//'),
        }


class CelerySQSConfig:
    def get_config(self):
        return {
            'broker_url': os.environ.get('BROKER', 'sqs://'),
            'broker_transport_options': {
                'region': os.environ.get('AWS_DEFAULT_REGION'),
                'predefined_queues': {
                    'celery': {
                        'url': self.get_sqs_url()
                    }
                }
            }
        }

    def get_sqs_url(self):
        start_time = time.time()
        while time.time() - start_time < float(os.environ.get('SQS_CHECK_DURATION', 60)):
            sqs = boto3.client(
                'sqs',
                endpoint_url=os.environ.get('AWS_ENDPOINT', None)
            )
            try:
                response = sqs.get_queue_url(
                    QueueName=os.environ.get('QUEUE_NAME'))
                return response['QueueUrl']
            except sqs.exceptions.QueueDoesNotExist:
                time.sleep(5)

        raise Exception("SQS Queue is not healthy")


def get_celery_app():
    broker_type = os.environ.get('BROKER_TYPE', 'default')

    config_class_list = {
        'sqs': CelerySQSConfig
    }

    app = Celery(__name__)
    config_class = config_class_list.get(broker_type, CeleryDefaultConfig)()
    app.conf.update(config_class.get_config())

    return app
