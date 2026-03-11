"""
Usage:
    python3 assistant.py            # Create a new assistant (run once)
    python3 assistant.py --upload   # Upload new files to existing assistant's Vector Store
"""

import os
import sys
import glob
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])

SYSTEM_PROMPT = """You are the UKLC Quick Answer Assistant. Your job is to help Group Leaders supervising students at UKLC summer centres by providing clear and helpful answers to common questions. Group Leaders may be responsible for groups of international students aged 10–18 and may not be familiar with UKLC procedures. Your responses should help them quickly understand what to do. Allow users to type/speak in their native language. Always follow these rules:
1. Keep answers SHORT and practical.
2. Use bullet points whenever possible.
3. Give clear step-by-step guidance when explaining procedures.
4. Assume the user is busy and needs quick information.
5. Use simple English that international users can easily understand.
6. Confirm which centre the user is at.

You can help with questions about: meal times and dining arrangements, daily schedules, excursions and meeting points, what students should bring for trips, accommodation questions, lost keys or lost items, curfews and behaviour rules, what to do if a student is sick, who to contact at the centre, information on English lessons and levels.

If the question involves student safety, health, behaviour issues, or emergencies, always advise the Group Leader to contact the relevant UKLC staff member (such as the Safeguarding & Welfare Coordinator, Course Director, or Centre Manager).

Never give medical or legal advice. Instead, explain the correct procedure and who to contact.

If you do not know the exact centre-specific information (such as exact times or locations), explain the typical UKLC procedure and advise the user to confirm details with the centre management team.

Always maintain a calm, professional and supportive tone."""


def get_file_paths() -> list[str]:
    knowledge_dir = "./knowledge"
    if not os.path.isdir(knowledge_dir):
        print("No ./knowledge directory found.")
        return []
    paths = [p for p in glob.glob(f"{knowledge_dir}/**/*", recursive=True) if os.path.isfile(p)]
    return paths


def upload_files_to_vector_store(vector_store_id: str) -> None:
    file_paths = get_file_paths()
    if not file_paths:
        print("No files to upload.")
        return
    print(f"Uploading {len(file_paths)} file(s)...")
    file_streams = [open(p, "rb") for p in file_paths]
    try:
        client.beta.vector_stores.file_batches.upload_and_poll(
            vector_store_id=vector_store_id,
            files=file_streams,
        )
        print("Files uploaded successfully.")
    finally:
        for f in file_streams:
            f.close()


def upload_to_existing_assistant() -> None:
    assistant_id = os.environ.get("ASSISTANT_ID")
    if not assistant_id:
        print("Error: ASSISTANT_ID not set in .env")
        sys.exit(1)

    print(f"Loading assistant {assistant_id}...")
    assistant = client.beta.assistants.retrieve(assistant_id)

    try:
        vector_store_ids = assistant.tool_resources.file_search.vector_store_ids
        if not vector_store_ids:
            raise ValueError("No vector store found")
        vector_store_id = vector_store_ids[0]
    except (AttributeError, ValueError):
        print("No Vector Store found on assistant — creating one...")
        vector_store = client.beta.vector_stores.create(name="UKLC Knowledge Base")
        client.beta.assistants.update(
            assistant_id,
            tool_resources={"file_search": {"vector_store_ids": [vector_store.id]}},
        )
        vector_store_id = vector_store.id

    print(f"Using Vector Store: {vector_store_id}")
    upload_files_to_vector_store(vector_store_id)


def create_assistant() -> None:
    print("Creating Vector Store...")
    vector_store = client.beta.vector_stores.create(name="UKLC Knowledge Base")
    print(f"Vector Store created: {vector_store.id}")

    upload_files_to_vector_store(vector_store.id)

    print("Creating Assistant...")
    assistant = client.beta.assistants.create(
        name="UKLC Quick Answer Assistant",
        instructions=SYSTEM_PROMPT,
        model="gpt-4o",
        tools=[{"type": "file_search"}],
        tool_resources={
            "file_search": {
                "vector_store_ids": [vector_store.id],
            }
        },
    )

    print("\n✓ Assistant created successfully!")
    print(f"\nASSISTANT_ID={assistant.id}")
    print("\nAdd the above line to your .env file before starting the server.")


if __name__ == "__main__":
    if "--upload" in sys.argv:
        upload_to_existing_assistant()
    else:
        create_assistant()
