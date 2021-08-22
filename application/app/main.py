from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from typing import Optional
import requests
from wonderwords import RandomWord
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from fastapi.responses import HTMLResponse

import os
import logging

from workers import thumbnail

logger = logging.getLogger(__name__)
logger.setLevel(logging.INFO)

STATIC_DIR = os.environ.get("STATIC_DIR", "/tmp/static")


class Thumbnail(BaseModel):
    url: str
    filename: Optional[str] = None


app = FastAPI()
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
templates = Jinja2Templates(directory="templates")


@app.post("/thumbnail", response_model=Thumbnail)
def create_thumbnail(tn: Thumbnail):
    try:
        rw = RandomWord()
        filename = '_'.join(rw.random_words(
            3, include_parts_of_speech=["nouns", "adjectives"]))
        tn.filename = filename

        thumbnail.create_s3_thumbnail.delay(
            tn.url,
            filename,
            os.environ.get("S3_BUCKET_NAME", None)
        )
        return tn
    except Exception as e:
        logger.error('Error encountered:{}'.format(e))
        raise HTTPException(
            status_code=500,
            detail="Internal Server Error")


@app.get("/thumbnail/{id}", response_class=HTMLResponse)
def load_thumbnail(request: Request, id: str):
    source = f'{os.environ.get("THUMBNAIL_BASE_URL", None)}/{id}'
    response = requests.get(source)

    if response.status_code == 200:
        return templates.TemplateResponse("thumbnail.html", {
            "request": request,
            "id": id,
            "source": source
        })

    raise HTTPException(status_code=404, detail="Thumbnail not found")
