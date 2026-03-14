import os
import json
import httpx
import redis.asyncio as aioredis
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
VECTOR_STORE_ID = os.environ.get("VECTOR_STORE_ID", "")
REDIS_URL = os.environ.get("REDIS_URL", "redis://localhost:6379")

WHATSAPP_API_URL = f"https://graph.facebook.com/v19.0/{WHATSAPP_PHONE_NUMBER_ID}/messages"

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

redis_client: aioredis.Redis = None


@app.on_event("startup")
async def startup():
    global redis_client
    redis_client = aioredis.from_url(REDIS_URL, decode_responses=True)


@app.on_event("shutdown")
async def shutdown():
    await redis_client.aclose()


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


async def get_conversation_history(sender: str) -> list:
    key = f"history:{sender}"
    data = await redis_client.get(key)
    if data:
        return json.loads(data)
    return []


async def save_conversation_history(sender: str, history: list) -> None:
    key = f"history:{sender}"
    # Keep last 20 messages to avoid token limits
    trimmed = history[-20:]
    await redis_client.set(key, json.dumps(trimmed), ex=86400)  # 24hr expiry


async def process_message(sender: str, text: str) -> str:
    history = await get_conversation_history(sender)

    history.append({"role": "user", "content": text})

    tools = []
    if VECTOR_STORE_ID:
        tools = [{
            "type": "file_search",
            "vector_store_ids": [VECTOR_STORE_ID]
        }]

    try:
        response = await client.responses.create(
            model="gpt-4o",
            instructions=SYSTEM_PROMPT,
            input=history,
            tools=tools if tools else None,
        )

        reply = response.output_text

        history.append({"role": "assistant", "content": reply})
        await save_conversation_history(sender, history)

        return reply

    except Exception as e:
        print(f"OpenAI error: {e}")
        return "Sorry, I was unable to process your request. Please try again."


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