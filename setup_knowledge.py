"""
Usage:
    python3 setup_knowledge.py   # Create a new Vector Store and upload knowledge files
    python3 setup_knowledge.py --upload  # Upload new files to existing Vector Store
"""

import os
import sys
import glob
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])


def get_file_paths() -> list[str]:
    knowledge_dir = "./knowledge"
    if not os.path.isdir(knowledge_dir):
        print("No ./knowledge directory found. Create one and add your PDF files.")
        return []
    paths = [p for p in glob.glob(f"{knowledge_dir}/**/*", recursive=True) if os.path.isfile(p)]
    return paths


def upload_files(vector_store_id: str) -> None:
    file_paths = get_file_paths()
    if not file_paths:
        print("No files to upload.")
        return
    print(f"Uploading {len(file_paths)} file(s)...")
    file_streams = [open(p, "rb") for p in file_paths]
    try:
        client.vector_stores.file_batches.upload_and_poll(
            vector_store_id=vector_store_id,
            files=file_streams,
        )
        print("Files uploaded successfully.")
    finally:
        for f in file_streams:
            f.close()


def create_vector_store() -> None:
    print("Creating Vector Store...")
    vector_store = client.vector_stores.create(name="UKLC Knowledge Base")
    print(f"Vector Store created: {vector_store.id}")

    upload_files(vector_store.id)

    print("\n✓ Done!")
    print(f"\nVECTOR_STORE_ID={vector_store.id}")
    print("\nAdd the above line to your .env file and Railway environment variables.")


def upload_to_existing() -> None:
    vector_store_id = os.environ.get("VECTOR_STORE_ID")
    if not vector_store_id:
        print("Error: VECTOR_STORE_ID not set in .env")
        sys.exit(1)
    print(f"Uploading to existing Vector Store: {vector_store_id}")
    upload_files(vector_store_id)


if __name__ == "__main__":
    if "--upload" in sys.argv:
        upload_to_existing()
    else:
        create_vector_store()