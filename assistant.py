"""
Run this script once to create the OpenAI Assistant and Vector Store.
It will print the ASSISTANT_ID to add to your .env file.

Usage:
    python assistant.py

Optional: place knowledge files (PDF, DOCX, TXT, etc.) in a ./knowledge/ directory
before running — they will be uploaded to the Vector Store automatically.
"""

import os
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


def upload_knowledge_files(vector_store_id: str) -> None:
    knowledge_dir = "./knowledge"
    if not os.path.isdir(knowledge_dir):
        print("No ./knowledge directory found — skipping file upload.")
        return

    file_paths = glob.glob(f"{knowledge_dir}/**/*", recursive=True)
    file_paths = [p for p in file_paths if os.path.isfile(p)]

    if not file_paths:
        print("No files found in ./knowledge — skipping file upload.")
        return

    print(f"Uploading {len(file_paths)} file(s) to Vector Store...")
    file_streams = [open(path, "rb") for path in file_paths]

    try:
        client.beta.vector_stores.file_batches.upload_and_poll(
            vector_store_id=vector_store_id,
            files=file_streams,
        )
        print("Files uploaded successfully.")
    finally:
        for f in file_streams:
            f.close()


def main() -> None:
    print("Creating Vector Store...")
    vector_store = client.beta.vector_stores.create(name="UKLC Knowledge Base")
    print(f"Vector Store created: {vector_store.id}")

    upload_knowledge_files(vector_store.id)

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
    main()
