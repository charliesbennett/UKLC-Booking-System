import os
import httpx
from fastapi import FastAPI, Request, Query, HTTPException
from fastapi.responses import PlainTextResponse
from openai import AsyncOpenAI
from dotenv import load_dotenv

load_dotenv()

app = FastAPI()
client = AsyncOpenAI(api_key=os.environ["OPENAI_API_KEY"])

WHATSAPP_TOKEN = os.environ["WHATSAPP_TOKEN"]
WHATSAPP_PHONE_NUMBER_ID = os.environ["WHATSAPP_PHONE_NUMBER_ID"]
VERIFY_TOKEN = os.environ["VERIFY_TOKEN"]
ASSISTANT_ID = os.environ["ASSISTANT_ID"]

WHATSAPP_API_URL = f"https://graph.facebook.com/v19.0/{WHATSAPP_PHONE_NUMBER_ID}/messages"

# In-memory store: sender phone number -> OpenAI thread ID
user_threads: dict[str, str] = {}


@app.get("/webhook")
async def verify_webhook(
    hub_mode: str = Query(None, alias="hub.mode"),
    hub_verify_token: str = Query(None, alias="hub.verify_token"),
    hub_challenge: str = Query(None, alias="hub.challenge"),
):
    if hub_mode == "subscribe" and hub_verify_token == VERIFY_TOKEN:
        return PlainTextResponse(content=hub_challenge)
    raise HTTPException(status_code=403, detail="Verification failed")


@app.post("/webhook")
async def receive_message(request: Request):
    body = await request.json()

    try:
        entry = body["entry"][0]
        changes = entry["changes"][0]
        value = changes["value"]

        # Ignore status updates
        if "messages" not in value:
            return {"status": "ok"}

        message = value["messages"][0]
        sender = message["from"]

        if message.get("type") != "text":
            return {"status": "ok"}

        text = message["text"]["body"]
    except (KeyError, IndexError):
        return {"status": "ok"}

    response_text = await process_message(sender, text)
    await send_whatsapp_message(sender, response_text)

    return {"status": "ok"}


async def process_message(sender: str, text: str) -> str:
    # Get or create thread for this sender
    if sender not in user_threads:
        thread = await client.beta.threads.create()
        user_threads[sender] = thread.id

    thread_id = user_threads[sender]

    # Add message to thread
    await client.beta.threads.messages.create(
        thread_id=thread_id,
        role="user",
        content=text,
    )

    # Run the assistant and wait for completion
    run = await client.beta.threads.runs.create_and_poll(
        thread_id=thread_id,
        assistant_id=ASSISTANT_ID,
    )

    if run.status != "completed":
        return "Sorry, I was unable to process your request. Please try again."

    # Retrieve the latest assistant message
    messages = await client.beta.threads.messages.list(
        thread_id=thread_id, order="desc", limit=1
    )

    for msg in messages.data:
        if msg.role == "assistant":
            for block in msg.content:
                if block.type == "text":
                    return block.text.value

    return "Sorry, I could not generate a response. Please try again."


async def send_whatsapp_message(to: str, text: str) -> None:
    payload = {
        "messaging_product": "whatsapp",
        "to": to,
        "type": "text",
        "text": {"body": text},
    }
    headers = {
        "Authorization": f"Bearer {WHATSAPP_TOKEN}",
        "Content-Type": "application/json",
    }
    async with httpx.AsyncClient() as http:
        response = await http.post(WHATSAPP_API_URL, json=payload, headers=headers)
        response.raise_for_status()
