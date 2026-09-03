import asyncio
from contextlib import asynccontextmanager
from dataclasses import dataclass
from threading import Lock
from typing import Literal

import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, field_validator


MODEL_ID = "BAAI/bge-m3"


@dataclass(frozen=True)
class Settings:
    model: str
    device: str = "cuda:0"
    dtype: Literal["float16", "bfloat16", "float32"] = "float16"
    batch_size: int = 8
    max_length: int = 8192
    max_inputs: int = 32


class EmbeddingRequest(BaseModel):
    input: str | list[str]
    model: str = MODEL_ID
    encoding_format: Literal["float"] = "float"

    @field_validator("input")
    @classmethod
    def validate_input(cls, value: str | list[str]) -> str | list[str]:
        values = [value] if isinstance(value, str) else value
        if not values:
            raise ValueError("input must not be empty")
        if any(not text for text in values):
            raise ValueError("input strings must not be empty")
        return value


class EmbeddingData(BaseModel):
    object: Literal["embedding"] = "embedding"
    index: int
    embedding: list[float]


class Usage(BaseModel):
    prompt_tokens: int
    total_tokens: int


class EmbeddingResponse(BaseModel):
    object: Literal["list"] = "list"
    data: list[EmbeddingData]
    model: str = MODEL_ID
    usage: Usage


class M3EmbeddingData(BaseModel):
    index: int
    dense: list[float]
    sparse: dict[str, float]
    colbert: list[list[float]]


class M3EmbeddingResponse(BaseModel):
    object: Literal["list"] = "list"
    data: list[M3EmbeddingData]
    model: str = MODEL_ID
    usage: Usage


class ModelBackend:
    def __init__(self, settings: Settings) -> None:
        from FlagEmbedding import BGEM3FlagModel

        if settings.dtype == "float16":
            use_fp16, use_bf16 = True, False
        elif settings.dtype == "bfloat16":
            use_fp16, use_bf16 = False, True
        else:
            use_fp16, use_bf16 = False, False

        self.settings = settings
        self.model = BGEM3FlagModel(
            settings.model,
            devices=settings.device,
            use_fp16=use_fp16,
            use_bf16=use_bf16,
            batch_size=settings.batch_size,
            passage_max_length=settings.max_length,
        )
        self.lock = Lock()

    def token_count(self, texts: list[str]) -> int:
        tokens = self.model.tokenizer(
            texts,
            add_special_tokens=True,
            truncation=True,
            max_length=self.settings.max_length,
        )
        return sum(len(input_ids) for input_ids in tokens["input_ids"])

    def encode(self, texts: list[str], all_vectors: bool) -> tuple[dict, int]:
        with self.lock:
            result = self.model.encode(
                texts,
                batch_size=self.settings.batch_size,
                max_length=self.settings.max_length,
                return_dense=True,
                return_sparse=all_vectors,
                return_colbert_vecs=all_vectors,
            )
            return result, self.token_count(texts)


def _texts(request: EmbeddingRequest, max_inputs: int) -> list[str]:
    if request.model != MODEL_ID:
        raise HTTPException(status_code=404, detail=f"model '{request.model}' not found")
    texts = [request.input] if isinstance(request.input, str) else request.input
    if len(texts) > max_inputs:
        raise HTTPException(status_code=400, detail=f"input supports at most {max_inputs} strings")
    return texts


def _usage(token_count: int) -> Usage:
    return Usage(prompt_tokens=token_count, total_tokens=token_count)


def create_app(settings: Settings, backend: ModelBackend | None = None) -> FastAPI:
    @asynccontextmanager
    async def lifespan(app: FastAPI):
        app.state.backend = backend or await asyncio.to_thread(ModelBackend, settings)
        yield

    app = FastAPI(title="BGE-M3 Server", version="0.1.0", lifespan=lifespan)

    @app.get("/health")
    async def health() -> dict[str, str]:
        return {"status": "ok", "model": MODEL_ID}

    @app.get("/v1/models")
    async def models() -> dict:
        return {
            "object": "list",
            "data": [{"id": MODEL_ID, "object": "model", "owned_by": "BAAI"}],
        }

    @app.post("/v1/embeddings", response_model=EmbeddingResponse)
    async def embeddings(request: EmbeddingRequest) -> EmbeddingResponse:
        texts = _texts(request, settings.max_inputs)
        result, token_count = await asyncio.to_thread(app.state.backend.encode, texts, False)
        dense = np.asarray(result["dense_vecs"], dtype=np.float32)
        return EmbeddingResponse(
            data=[EmbeddingData(index=index, embedding=vector.tolist()) for index, vector in enumerate(dense)],
            usage=_usage(token_count),
        )

    @app.post("/v1/embeddings/m3", response_model=M3EmbeddingResponse)
    async def m3_embeddings(request: EmbeddingRequest) -> M3EmbeddingResponse:
        texts = _texts(request, settings.max_inputs)
        result, token_count = await asyncio.to_thread(app.state.backend.encode, texts, True)
        dense = np.asarray(result["dense_vecs"], dtype=np.float32)
        data = []
        for index, vector in enumerate(dense):
            sparse = {key: float(value) for key, value in result["lexical_weights"][index].items()}
            colbert = np.asarray(result["colbert_vecs"][index], dtype=np.float32).tolist()
            data.append(
                M3EmbeddingData(index=index, dense=vector.tolist(), sparse=sparse, colbert=colbert)
            )
        return M3EmbeddingResponse(data=data, usage=_usage(token_count))

    return app
