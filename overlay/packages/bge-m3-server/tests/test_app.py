from contextlib import contextmanager

import numpy as np
from fastapi.testclient import TestClient

from bge_m3_server.app import MODEL_ID, Settings, create_app


class FakeBackend:
    def encode(self, texts: list[str], all_vectors: bool):
        result = {
            "dense_vecs": np.asarray([[1.0, 2.0] for _ in texts]),
            "lexical_weights": [{"42": np.float16(0.5)} for _ in texts] if all_vectors else None,
            "colbert_vecs": [np.asarray([[0.1, 0.2]]) for _ in texts] if all_vectors else None,
        }
        return result, len(texts) * 3


@contextmanager
def client(max_inputs: int = 32):
    app = create_app(Settings(model="unused", max_inputs=max_inputs), FakeBackend())
    with TestClient(app) as test_client:
        yield test_client


def test_openai_embeddings():
    with client() as test_client:
        response = test_client.post("/v1/embeddings", json={"model": MODEL_ID, "input": ["a", "b"]})
    assert response.status_code == 200
    assert response.json() == {
        "object": "list",
        "data": [
            {"object": "embedding", "index": 0, "embedding": [1.0, 2.0]},
            {"object": "embedding", "index": 1, "embedding": [1.0, 2.0]},
        ],
        "model": MODEL_ID,
        "usage": {"prompt_tokens": 6, "total_tokens": 6},
    }


def test_m3_embeddings():
    with client() as test_client:
        response = test_client.post("/v1/embeddings/m3", json={"input": "text"})
    assert response.status_code == 200
    data = response.json()["data"][0]
    assert data["dense"] == [1.0, 2.0]
    assert data["sparse"] == {"42": 0.5}
    assert np.allclose(data["colbert"], [[0.1, 0.2]])


def test_rejects_too_many_inputs():
    with client(max_inputs=1) as test_client:
        response = test_client.post("/v1/embeddings", json={"input": ["a", "b"]})
    assert response.status_code == 400
