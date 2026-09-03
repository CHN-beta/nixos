import argparse

import uvicorn

from .app import Settings, create_app


def main() -> None:
    parser = argparse.ArgumentParser(description="Serve BGE-M3 embeddings over HTTP")
    parser.add_argument("--model", required=True)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", default=8080, type=int)
    parser.add_argument("--device", default="cuda:0")
    parser.add_argument("--dtype", choices=("float16", "bfloat16", "float32"), default="float16")
    parser.add_argument("--batch-size", default=8, type=int)
    parser.add_argument("--max-length", default=8192, type=int)
    parser.add_argument("--max-inputs", default=32, type=int)
    parser.add_argument("--log-level", default="info")
    args = parser.parse_args()

    settings = Settings(
        model=args.model,
        device=args.device,
        dtype=args.dtype,
        batch_size=args.batch_size,
        max_length=args.max_length,
        max_inputs=args.max_inputs,
    )
    uvicorn.run(create_app(settings), host=args.host, port=args.port, log_level=args.log_level)


if __name__ == "__main__":
    main()
