# Claude Code как Backend: Браузер, Telegram и Multi-Agent Workflow

> **Дата исследования:** 2026-02-21
> **Проверено по официальной документации:** platform.claude.com/docs/en/agent-sdk/
> **Статус:** Исследование + Проектирование архитектуры

## Оглавление

1. [Обзор возможностей](#1-обзор-возможностей)
2. [Ключевые API и инструменты](#2-ключевые-api-и-инструменты)
3. [Вариант A: Telegram-бот](#3-вариант-a-telegram-бот)
4. [Вариант B: FastAPI веб-бэкенд](#4-вариант-b-fastapi-веб-бэкенд)
5. [Вариант C: Headless CLI + WebSocket](#5-вариант-c-headless-cli--websocket)
6. [Multi-Agent Workflow](#6-multi-agent-workflow)
7. [Сравнение вариантов](#7-сравнение-вариантов)
8. [Рекомендуемая архитектура для iclaude](#8-рекомендуемая-архитектура-для-iclaude)
9. [Пример интеграции в iclaude](#9-пример-интеграции-в-iclaude)

---

## 1. Обзор возможностей

Claude Code предоставляет несколько уровней программной интеграции:

```
┌─────────────────────────────────────────────────────────────┐
│                    Уровни интеграции                        │
├─────────────────────────────────────────────────────────────┤
│  Уровень 1: claude -p (Headless CLI)                        │
│    stdin/stdout, JSON output, скрипты и CI                  │
│                                                             │
│  Уровень 2: Claude Agent SDK — query()                      │
│    Одиночные задачи, session resume, agents, MCP            │
│                                                             │
│  Уровень 3: Claude Agent SDK — ClaudeSDKClient              │
│    Непрерывный диалог, hooks, interrupt, custom tools       │
│                                                             │
│  Уровень 4: Multi-Agent (AgentDefinition API)               │
│    Специализированные субагенты, параллельность             │
└─────────────────────────────────────────────────────────────┘
```

### Ключевой факт

Claude Code **не имеет встроенного HTTP-сервера**. Чтобы использовать его как бэкенд для браузера или Telegram, нужен промежуточный слой:

```
Пользователь (браузер/Telegram)
        ↕
   Ваш сервер (FastAPI/Node/bash)
        ↕
  Claude Agent SDK / claude -p
        ↕
    Claude Code Engine
```

### Критическое различие: `query()` vs `ClaudeSDKClient`

| Возможность | `query()` | `ClaudeSDKClient` |
|-------------|-----------|-------------------|
| Один запрос | ✅ | ✅ |
| Продолжение сессии (`resume`) | ✅ | ✅ |
| Субагенты (`agents`) | ✅ | ✅ |
| MCP серверы | ✅ | ✅ |
| **Hooks** | ✅ | ✅ |
| **Custom Tools** | ❌ | ✅ |
| **Прерывание** (`interrupt`) | ❌ | ✅ |
| Непрерывный диалог | ❌ | ✅ |

> **Hooks работают как с `query()`, так и с `ClaudeSDKClient`. Только `ClaudeSDKClient` поддерживает прерывание (`interrupt`), custom tools и непрерывный диалог.**

---

## 2. Ключевые API и инструменты

### 2.1 Claude Agent SDK

```bash
pip install claude-agent-sdk         # Python (требуется >=3.10)
npm install @anthropic-ai/claude-agent-sdk  # TypeScript
```

**Использование `query()` — одиночные задачи:**

```python
from claude_agent_sdk import query, ClaudeAgentOptions, ResultMessage

options = ClaudeAgentOptions(
    allowed_tools=["Read", "Write", "Bash", "Glob", "Grep", "Task"],
    permission_mode="default",   # "default" | "acceptEdits" | "bypassPermissions" | "plan"
    cwd="/path/to/project",      # рабочая директория (в Options, не в query()!)
    mcp_servers={},              # внешние MCP-серверы
    agents={},                   # субагенты
    resume=None,                 # session_id для продолжения
)

async for message in query(prompt="Analyze the codebase", options=options):
    if isinstance(message, ResultMessage):
        print(message.result)
        session_id = message.session_id  # сохранить для resume
```

**Типы сообщений SDK:**

| Класс | Описание |
|-------|----------|
| `AssistantMessage` | Ответ модели (content: список TextBlock/ToolUseBlock) |
| `UserMessage` | Результаты инструментов (ToolResultBlock) |
| `SystemMessage` | Системные события (subtype: "init" и др.) |
| `ResultMessage` | Финальный результат (result, session_id, cost) |
| `StreamEvent` | Частичные события (только при `include_partial_messages=True`) |

**Захват `session_id` для продолжения сессии:**

```python
from claude_agent_sdk import query, ClaudeAgentOptions, ResultMessage

session_id = None

# Первый запрос
async for message in query(
    prompt="Read the authentication module",
    options=ClaudeAgentOptions(allowed_tools=["Read", "Glob"]),
):
    if isinstance(message, ResultMessage):
        session_id = message.session_id  # ✅ правильно

# Продолжить ту же сессию
async for message in query(
    prompt="Now find all places that call it",
    options=ClaudeAgentOptions(resume=session_id),  # ✅ в Options!
):
    if isinstance(message, ResultMessage):
        print(message.result)
```

**Использование `ClaudeSDKClient` — непрерывный диалог и hooks:**

```python
from claude_agent_sdk import ClaudeSDKClient, ClaudeAgentOptions, AssistantMessage, TextBlock

options = ClaudeAgentOptions(
    allowed_tools=["Read", "Bash"],
    permission_mode="acceptEdits",
)

async with ClaudeSDKClient(options=options) as client:
    await client.query("Анализируй auth.py")

    async for message in client.receive_response():
        if isinstance(message, AssistantMessage):
            for block in message.content:
                if isinstance(block, TextBlock):
                    print(block.text)

    # Продолжить диалог — Claude помнит контекст
    await client.query("Теперь добавь тесты для этого модуля")
    async for message in client.receive_response():
        ...
```

### 2.2 Headless CLI (claude -p)

```bash
# Простой промпт
claude -p "Describe the project structure" --output-format text

# JSON вывод (session_id в .session_id поля финального объекта)
claude -p "List all functions" --output-format json | jq '.result'

# Структурированный вывод по JSON Schema
claude -p "Extract API endpoints" \
  --output-format json \
  --json-schema '{"type":"object","properties":{"endpoints":{"type":"array"}}}' \
  | jq '.structured_output'

# Продолжение сессии
SESSION_ID=$(claude -p "Start analysis" --output-format json | jq -r '.session_id')
claude -p "Continue analysis" --resume "$SESSION_ID"
```

### 2.3 Hooks API

> ℹ️ **Hooks работают с обоими API: `query()` и `ClaudeSDKClient`.** Пример ниже использует `query()`.

```python
from claude_agent_sdk import (
    query, ClaudeAgentOptions, HookMatcher, HookContext, ResultMessage
)
from typing import Any
import requests

async def notify_telegram_on_stop(
    input_data: dict[str, Any],
    tool_use_id: str | None,
    context: HookContext
) -> dict:
    """Вызывается когда Claude завершил задачу. НЕТ доступа к result здесь."""
    # StopHookInput содержит: session_id, cwd, stop_hook_active
    requests.post(
        f"https://api.telegram.org/bot{TOKEN}/sendMessage",
        json={"chat_id": CHAT_ID, "text": "Claude завершил задачу."}
    )
    return {}

async def log_file_change(
    input_data: dict[str, Any],
    tool_use_id: str | None,
    context: HookContext
) -> dict:
    """PostToolUse хук — вызывается после Write/Edit."""
    print(f"Файл изменён: {input_data.get('file_path', '?')}")
    return {}

# ✅ hooks работают с query()
async for message in query(
    prompt="Выполни задачу",
    options=ClaudeAgentOptions(
        hooks={
            # ✅ Используем HookMatcher, не словарь
            "Stop": [HookMatcher(matcher=None, hooks=[notify_telegram_on_stop])],
            "PostToolUse": [HookMatcher(matcher="Write|Edit", hooks=[log_file_change])],
        }
    ),
):
    if isinstance(message, ResultMessage):
        print(message.result)
```

**Доступные хуки в Python SDK:**

| Хук | Событие |
|-----|---------|
| `PreToolUse` | Перед вызовом инструмента (можно заблокировать) |
| `PostToolUse` | После вызова инструмента |
| `Stop` | Claude завершил работу |
| `SubagentStop` | Субагент завершил работу |
| `UserPromptSubmit` | Перед отправкой промпта |
| `PreCompact` | Перед сжатием контекста |

> ❌ `SessionStart`, `SessionEnd`, `Notification` — **не поддерживаются** в Python SDK.

---

## 3. Вариант A: Telegram-бот

### 3.1 Архитектура

```
┌──────────────────────────────────────────────────┐
│  Telegram API (polling/webhook)                  │
└──────────────────────┬───────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────┐
│  Telegram Bot Server (Python + python-telegram-bot)│
│  ┌──────────────────────────────────────────┐    │
│  │  Session Manager                          │    │
│  │  user_id → {claude_session_id, project}   │    │
│  └──────────────────────────────────────────┘    │
│  ┌──────────────────────────────────────────┐    │
│  │  Auth (whitelist by user_id)              │    │
│  └──────────────────────────────────────────┘    │
└──────────────────────┬───────────────────────────┘
                       ↓
┌──────────────────────────────────────────────────┐
│  Claude Agent SDK (query + session resume)        │
│  ┌─────────────┐  ┌─────────────┐               │
│  │  Session A  │  │  Session B  │  ...           │
│  │  user #123  │  │  user #456  │               │
│  └─────────────┘  └─────────────┘               │
└──────────────────────────────────────────────────┘
```

### 3.2 Реализация

**Требования:**
```bash
pip install "python-telegram-bot[webhooks]" claude-agent-sdk
```

**Основная структура бота:**

```python
# telegram_claude_bot.py
import os, sqlite3
from telegram import Update
from telegram.ext import Application, CommandHandler, MessageHandler, filters
from claude_agent_sdk import query, ClaudeAgentOptions, ResultMessage

# Конфигурация
TELEGRAM_TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
WHITELIST = set(map(int, filter(None, os.getenv("ALLOWED_USER_IDS", "").split(","))))
PROJECT_DIR = os.getenv("PROJECT_DIR", os.getcwd())


class SessionManager:
    """Привязка user_id → claude_session_id + project_dir"""

    def __init__(self, db_path="sessions.db"):
        self.conn = sqlite3.connect(db_path, check_same_thread=False)
        self.conn.execute("""
            CREATE TABLE IF NOT EXISTS sessions (
                user_id INTEGER PRIMARY KEY,
                session_id TEXT,
                project_dir TEXT,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        """)
        self.conn.commit()

    def get_session(self, user_id: int) -> dict | None:
        row = self.conn.execute(
            "SELECT session_id, project_dir FROM sessions WHERE user_id = ?",
            (user_id,)
        ).fetchone()
        return {"session_id": row[0], "project_dir": row[1]} if row else None

    def save_session(self, user_id: int, session_id: str, project_dir: str):
        self.conn.execute("""
            INSERT OR REPLACE INTO sessions (user_id, session_id, project_dir, updated_at)
            VALUES (?, ?, ?, CURRENT_TIMESTAMP)
        """, (user_id, session_id, project_dir))
        self.conn.commit()

    def clear_session(self, user_id: int):
        self.conn.execute("DELETE FROM sessions WHERE user_id = ?", (user_id,))
        self.conn.commit()


sessions = SessionManager()


async def run_claude(prompt: str, user_id: int, project_dir: str) -> str:
    """Выполнить запрос к Claude и вернуть результат"""
    session_data = sessions.get_session(user_id)

    options = ClaudeAgentOptions(
        allowed_tools=["Read", "Write", "Bash", "Glob", "Grep", "Task"],
        permission_mode="default",
        cwd=project_dir,           # ✅ cwd в ClaudeAgentOptions, не в query()
        resume=session_data["session_id"] if session_data else None,
    )

    result_text = ""

    async for message in query(prompt=prompt, options=options):
        if isinstance(message, ResultMessage):   # ✅ проверяем тип через isinstance
            result_text = message.result or ""
            # ✅ session_id всегда есть в ResultMessage
            sessions.save_session(user_id, message.session_id, project_dir)

    return result_text or "Задача выполнена."


async def handle_message(update: Update, context):
    user_id = update.effective_user.id

    if WHITELIST and user_id not in WHITELIST:
        await update.message.reply_text("Доступ запрещён.")
        return

    await context.bot.send_chat_action(
        chat_id=update.effective_chat.id, action="typing"
    )

    try:
        result = await run_claude(
            update.message.text, user_id, PROJECT_DIR
        )
        # Telegram лимит 4096 символов
        for chunk in [result[i:i+4096] for i in range(0, len(result), 4096)]:
            await update.message.reply_text(chunk, parse_mode="Markdown")
    except Exception as e:
        await update.message.reply_text(f"Ошибка: {e}")


async def cmd_new(update: Update, context):
    sessions.clear_session(update.effective_user.id)
    await update.message.reply_text("Новая сессия начата.")


async def cmd_cd(update: Update, context):
    if not context.args:
        await update.message.reply_text("Использование: /cd /path/to/project")
        return
    new_dir = context.args[0]
    if not os.path.isdir(new_dir):
        await update.message.reply_text(f"Директория не найдена: {new_dir}")
        return
    session = sessions.get_session(update.effective_user.id) or {}
    sessions.save_session(update.effective_user.id, session.get("session_id", ""), new_dir)
    await update.message.reply_text(f"Рабочая директория: {new_dir}")


def main():
    app = Application.builder().token(TELEGRAM_TOKEN).build()
    app.add_handler(CommandHandler("new", cmd_new))
    app.add_handler(CommandHandler("cd", cmd_cd))
    app.add_handler(MessageHandler(filters.TEXT & ~filters.COMMAND, handle_message))
    app.run_polling()


if __name__ == "__main__":
    main()
```

### 3.3 Паттерн: Hook-уведомления через `ClaudeSDKClient`

Если нужно только **получать уведомления** от Claude (push-режим).
Hooks работают как с `ClaudeSDKClient`, так и с `query()`. Здесь показан вариант с `ClaudeSDKClient`:

```python
from claude_agent_sdk import (
    ClaudeSDKClient, ClaudeAgentOptions, HookMatcher, HookContext
)
import requests
from typing import Any

TOKEN = os.getenv("TELEGRAM_BOT_TOKEN")
CHAT_ID = os.getenv("TELEGRAM_CHAT_ID")


async def notify_telegram_on_stop(
    input_data: dict[str, Any],
    tool_use_id: str | None,
    context: HookContext
) -> dict:
    """Хук Stop — информирует что задача завершена."""
    # StopHookInput не содержит result — только stop_hook_active, session_id, cwd
    requests.post(
        f"https://api.telegram.org/bot{TOKEN}/sendMessage",
        json={"chat_id": CHAT_ID, "text": "Claude завершил задачу."}
    )
    return {}


options = ClaudeAgentOptions(
    hooks={
        "Stop": [HookMatcher(hooks=[notify_telegram_on_stop])]  # ✅ HookMatcher
    }
)

# ✅ ClaudeSDKClient поддерживает hooks
async with ClaudeSDKClient(options=options) as client:
    await client.query("Выполни задачу...")
    async for message in client.receive_response():
        pass  # хук Stop вызовется автоматически
```

### 3.4 Команды Telegram-бота

| Команда | Описание |
|---------|----------|
| `/new` | Начать новую сессию (сбросить контекст) |
| `/cd /path` | Сменить рабочую директорию |
| `/ls` | Список файлов в текущей директории |
| `/git log` | Показать git лог |
| `/continue` | Продолжить последнюю задачу |
| Текст | Запрос к Claude Code |

---

## 4. Вариант B: FastAPI веб-бэкенд

### 4.1 Архитектура

```
┌─────────────────────────────────────────────────────────┐
│  Браузер (React/Vue/vanilla JS)                         │
│  ┌─────────────────┐  ┌─────────────────────────────┐  │
│  │  Chat UI         │  │  SSE stream                  │  │
│  └─────────────────┘  └─────────────────────────────┘  │
└──────────────────────────┬──────────────────────────────┘
                           ↓ HTTP
┌─────────────────────────────────────────────────────────┐
│  FastAPI Backend                                         │
│  POST /chat              - новый запрос                 │
│  GET  /chat/{id}/stream  - SSE стрим ответа             │
│  GET  /sessions          - список сессий                │
│  DELETE /sessions/{id}   - удалить сессию               │
└──────────────────────────┬──────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│  Claude Agent SDK (query + ResultMessage)                │
│  Сессии в памяти / Redis                                │
└─────────────────────────────────────────────────────────┘
```

### 4.2 Реализация FastAPI

```python
# backend.py
from fastapi import FastAPI, HTTPException
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from claude_agent_sdk import (
    query, ClaudeAgentOptions,
    AssistantMessage, ResultMessage, TextBlock
)
import asyncio, uuid, json

app = FastAPI(title="Claude Code Backend")

# Хранилище запросов (в продакшне — Redis)
requests_store: dict[str, dict] = {}


class ChatRequest(BaseModel):
    prompt: str
    session_id: str | None = None
    project_dir: str = "."
    tools: list[str] = ["Read", "Glob", "Grep", "Bash"]


@app.post("/chat")
async def start_chat(req: ChatRequest):
    """Создать новый запрос, вернуть request_id"""
    request_id = str(uuid.uuid4())
    requests_store[request_id] = {
        "status": "pending",
        "claude_session_id": req.session_id,
        "project_dir": req.project_dir,
        "prompt": req.prompt,
        "tools": req.tools,
        "chunks": [],   # текстовые фрагменты для SSE
    }
    asyncio.create_task(_run_claude(request_id))
    return {"request_id": request_id}


async def _run_claude(request_id: str):
    """Фоновое выполнение запроса"""
    data = requests_store[request_id]
    options = ClaudeAgentOptions(
        allowed_tools=data["tools"],
        cwd=data["project_dir"],           # ✅ cwd в Options
        resume=data["claude_session_id"],
    )
    requests_store[request_id]["status"] = "running"

    try:
        async for message in query(prompt=data["prompt"], options=options):
            if isinstance(message, AssistantMessage):
                for block in message.content:
                    if isinstance(block, TextBlock):
                        requests_store[request_id]["chunks"].append(block.text)
            elif isinstance(message, ResultMessage):
                # ✅ session_id и result в ResultMessage
                requests_store[request_id]["claude_session_id"] = message.session_id
                requests_store[request_id]["final_result"] = message.result

        requests_store[request_id]["status"] = "done"
    except Exception as e:
        requests_store[request_id]["status"] = "error"
        requests_store[request_id]["error"] = str(e)


@app.get("/chat/{request_id}/stream")
async def stream_response(request_id: str):
    """SSE стрим текстовых фрагментов ответа"""
    if request_id not in requests_store:
        raise HTTPException(404, "Request not found")

    async def generate():
        seen = 0
        while True:
            data = requests_store[request_id]
            chunks = data["chunks"]

            while seen < len(chunks):
                yield f"data: {json.dumps({'type': 'text', 'text': chunks[seen]})}\n\n"
                seen += 1

            if data["status"] in ("done", "error"):
                yield f"data: {json.dumps({'type': 'end', 'status': data['status']})}\n\n"
                break

            await asyncio.sleep(0.1)

    return StreamingResponse(generate(), media_type="text/event-stream")


@app.get("/sessions")
async def list_sessions():
    return {"sessions": [
        {
            "id": k,
            "status": v["status"],
            "claude_session_id": v.get("claude_session_id")
        }
        for k, v in requests_store.items()
    ]}


@app.delete("/sessions/{request_id}")
async def delete_session(request_id: str):
    requests_store.pop(request_id, None)
    return {"status": "deleted"}
```

### 4.3 Простой фронтенд (vanilla JS)

```html
<!-- index.html -->
<!DOCTYPE html>
<html>
<head>
  <title>Claude Code Web</title>
  <style>
    body { font-family: monospace; max-width: 800px; margin: 40px auto; padding: 20px; }
    #output { background: #1a1a1a; color: #00ff00; padding: 20px; min-height: 300px;
              white-space: pre-wrap; overflow-y: auto; max-height: 500px; }
    #input { width: 100%; padding: 10px; font-family: monospace; font-size: 14px; }
    button { padding: 10px 20px; background: #007bff; color: white; border: none; cursor: pointer; }
  </style>
</head>
<body>
  <h1>Claude Code</h1>
  <div id="output">Готов к работе...</div>
  <br>
  <input id="input" type="text" placeholder="Введите запрос...">
  <button onclick="sendMessage()">Отправить</button>

  <script>
    let currentSessionId = null;

    async function sendMessage() {
      const input = document.getElementById('input');
      const output = document.getElementById('output');
      const prompt = input.value;
      if (!prompt) return;

      input.value = '';
      output.textContent += `\n\n> ${prompt}\n`;

      const resp = await fetch('/chat', {
        method: 'POST',
        headers: {'Content-Type': 'application/json'},
        body: JSON.stringify({
          prompt,
          session_id: currentSessionId,
          project_dir: '.'
        })
      });
      const { request_id } = await resp.json();

      const es = new EventSource(`/chat/${request_id}/stream`);
      es.onmessage = (e) => {
        const data = JSON.parse(e.data);
        if (data.type === 'text') {
          output.textContent += data.text;
          output.scrollTop = output.scrollHeight;
        }
        if (data.type === 'end') {
          es.close();
          // Обновить claude_session_id для следующего запроса
          fetch('/sessions').then(r => r.json()).then(s => {
            const sess = s.sessions.find(x => x.id === request_id);
            if (sess?.claude_session_id) currentSessionId = sess.claude_session_id;
          });
        }
      };
    }

    document.getElementById('input').addEventListener('keydown', e => {
      if (e.key === 'Enter') sendMessage();
    });
  </script>
</body>
</html>
```

---

## 5. Вариант C: Headless CLI + WebSocket

Самый простой вариант без Python SDK — обернуть `claude -p` в WebSocket сервер:

```javascript
// ws-server.js (Node.js)
const WebSocket = require('ws');
const { spawn } = require('child_process');

const wss = new WebSocket.Server({ port: 8080 });
const sessions = new Map(); // clientId → session_id

wss.on('connection', (ws, req) => {
  const clientId = req.headers['x-client-id'] || Math.random().toString(36);

  ws.on('message', (msg) => {
    const { prompt, projectDir = '.' } = JSON.parse(msg);
    const sessionId = sessions.get(clientId);

    const args = ['-p', prompt, '--output-format', 'stream-json'];
    if (sessionId) args.push('--resume', sessionId);

    const claude = spawn('claude', args, { cwd: projectDir });

    claude.stdout.on('data', (chunk) => {
      chunk.toString().split('\n').filter(Boolean).forEach(line => {
        try {
          const event = JSON.parse(line);
          // В stream-json финальный объект содержит session_id
          if (event.session_id) {
            sessions.set(clientId, event.session_id);
          }
          ws.send(JSON.stringify(event));
        } catch(e) { /* пропустить невалидные строки */ }
      });
    });

    claude.on('close', () => ws.send(JSON.stringify({ type: 'end' })));
  });
});

console.log('WebSocket сервер запущен на ws://localhost:8080');
```

**Ограничения этого варианта:**
- Нет hooks (CLI не поддерживает callback API)
- Нет `AgentDefinition` (специализированных субагентов)
- session_id извлекается из финального JSON объекта (не из stream события)

---

## 6. Multi-Agent Workflow

### 6.1 AgentDefinition API

Специализированные субагенты с изолированным контекстом.
Оркестратор вызывает их через инструмент `Task`:

```python
from claude_agent_sdk import query, ClaudeAgentOptions, AgentDefinition

options = ClaudeAgentOptions(
    allowed_tools=["Read", "Glob", "Grep", "Task"],  # Task обязателен для субагентов
    agents={
        "code-reviewer": AgentDefinition(
            description="Проверяет качество кода: style, patterns, complexity",
            prompt="""Ты специализируешься исключительно на code review.
Анализируй: PEP8/ESLint compliance, naming conventions,
code duplication, cyclomatic complexity.
Не исправляй код — только сообщай о проблемах.""",
            tools=["Read", "Glob", "Grep"],
            # model="sonnet"  # опционально: "sonnet"|"opus"|"haiku"|"inherit"
        ),
        "security-scanner": AgentDefinition(
            description="Ищет уязвимости безопасности в коде",
            prompt="""Ты специализируешься на security analysis.
Ищи: SQL injection, XSS, hardcoded secrets, insecure dependencies,
path traversal, SSRF, broken auth.""",
            tools=["Read", "Glob", "Grep"],
        ),
        "doc-writer": AgentDefinition(
            description="Генерирует документацию для кода",
            prompt="""Ты специализируешься на документации.
Пиши: docstrings, README разделы, API docs.
Формат: Markdown.""",
            tools=["Read", "Glob", "Grep", "Write"],
        ),
        "test-writer": AgentDefinition(
            description="Пишет unit и integration тесты",
            prompt="""Ты специализируешься на тестировании.
Пиши: pytest/jest тесты, мокирование зависимостей, edge cases.""",
            tools=["Read", "Glob", "Grep", "Write", "Bash"],
        ),
    }
)
```

> **`prompt` — обязательный параметр** `AgentDefinition`. Без него код упадёт с ошибкой.

### 6.2 Схема оркестрации

```
┌─────────────────────────────────────────────────────────┐
│  Orchestrator                                           │
│  "Выполни полный code review проекта"                   │
│                                                         │
│  Анализирует задачу → декомпозиция на подзадачи         │
└─────────────────────────────────────────────────────────┘
         │              │              │              │
         ↓              ↓              ↓              ↓
┌──────────────┐ ┌────────────┐ ┌──────────────┐ ┌──────────────┐
│code-reviewer │ │security-   │ │doc-writer    │ │test-writer   │
│(параллельно) │ │scanner     │ │(после review)│ │(после review)│
└──────────────┘ └────────────┘ └──────────────┘ └──────────────┘
         │              │              │              │
         └──────────────┴──────────────┴──────────────┘
                                ↓
                    Агрегация результатов
                    Финальный отчёт
```

### 6.3 Паттерны workflow

**Паттерн 1: Параллельный code review**

```python
from claude_agent_sdk import query, ClaudeAgentOptions, AgentDefinition, ResultMessage

async def parallel_review(project_path: str) -> str:
    options = ClaudeAgentOptions(
        allowed_tools=["Read", "Glob", "Grep", "Task"],
        cwd=project_path,   # ✅ cwd в Options
        agents={...},       # субагенты из 6.1
    )

    async for message in query(
        prompt="""Проведи комплексный анализ проекта:
1. Запусти code-reviewer и security-scanner ПАРАЛЛЕЛЬНО
2. После их завершения запусти doc-writer для новой документации
3. Запусти test-writer для критических функций без тестов
4. Создай сводный отчёт""",
        options=options,
    ):
        if isinstance(message, ResultMessage):
            return message.result or ""
    return ""
```

**Паттерн 2: Исследование + планирование + выполнение**

```python
options = ClaudeAgentOptions(
    allowed_tools=["Read", "Glob", "Grep", "Task", "Write", "Bash"],
    agents={
        "researcher": AgentDefinition(
            description="Исследует кодовую базу, не изменяет файлы",
            prompt="Изучи архитектуру и опиши существующие паттерны. Только чтение.",
            tools=["Read", "Glob", "Grep"],
        ),
        "planner": AgentDefinition(
            description="Создаёт план изменений на основе исследования",
            prompt="Создай детальный технический план изменений в виде markdown файла.",
            tools=["Read", "Write"],
        ),
        "executor": AgentDefinition(
            description="Выполняет изменения по готовому плану",
            prompt="Реализуй изменения строго по плану. Не отступай от него.",
            tools=["Read", "Write", "Bash"],
        ),
    }
)
```

**Паттерн 3: Выбор модели для субагента**

```python
# AgentDefinition.model управляет моделью субагента
agents={
    "planner": AgentDefinition(
        description="Планировщик (требует сложного рассуждения)",
        prompt="...",
        model="opus",    # более мощная модель для планирования
    ),
    "executor": AgentDefinition(
        description="Исполнитель (стандартные операции)",
        prompt="...",
        model="sonnet",  # экономичная модель для выполнения
    ),
}
```

### 6.4 Безопасность через `can_use_tool`

`can_use_tool` работает с обоими API (`query()` и `ClaudeSDKClient`):

```python
from claude_agent_sdk import query, ClaudeAgentOptions
from claude_agent_sdk.types import PermissionResultAllow, PermissionResultDeny, ToolPermissionContext

async def security_guard(
    tool_name: str,
    tool_input: dict,
    context: ToolPermissionContext
) -> PermissionResultAllow | PermissionResultDeny:
    """Блокировать опасные операции"""

    if tool_name == "Bash":
        cmd = tool_input.get("command", "")
        dangerous = ["rm -rf", "sudo rm", "chmod 777", "curl | bash"]
        for pattern in dangerous:
            if pattern in cmd:
                return PermissionResultDeny(
                    message=f"Заблокировано: {pattern}",
                    interrupt=True
                )

    if tool_name == "Write":
        path = tool_input.get("file_path", "")
        if not (path.startswith("/tmp/") or path.startswith(PROJECT_DIR)):
            return PermissionResultDeny(
                message="Запись вне проекта запрещена"
            )

    return PermissionResultAllow(updated_input=tool_input)


options = ClaudeAgentOptions(
    can_use_tool=security_guard   # ✅ работает с query() и ClaudeSDKClient
)
```

---

## 7. Сравнение вариантов

| Критерий | Telegram-бот | FastAPI веб | Headless CLI+WS | Hooks only |
|----------|-------------|------------|----------------|------------|
| **Сложность** | Средняя | Высокая | Низкая | Минимальная |
| **Интерфейс** | Telegram UI | Кастомный | Кастомный | Нет UI |
| **Мобильность** | Отличная | Хорошая | Плохая | Н/Д |
| **Аутентификация** | Встроенная (user_id) | Нужна своя | Нет | Нет |
| **Сессии** | SQLite | In-memory/Redis | Map | Нет |
| **Потоковый вывод** | Нет (блоки) | Да (SSE) | Да (WS) | Нет |
| **Инструменты** | Все Claude | Все Claude | Все Claude | Ограничено |
| **Multi-agent** | Да (SDK) | Да (SDK) | Нет (CLI) | Нет |
| **Hooks** | Да (ClaudeSDKClient) | Да (ClaudeSDKClient) | Нет | Да |
| **Стоимость инфраструктуры** | ~$5/мес VPS | ~$20/мес VPS | Локально | 0 |

---

## 8. Рекомендуемая архитектура для iclaude

### Для персонального использования: Telegram + session resume

```
iclaude.sh
    ├── --telegram-bot    # запустить Telegram бот демон
    ├── --telegram-notify # Telegram hook-уведомление при завершении
    └── --no-telegram     # работа без Telegram (по умолчанию)
```

**Конфигурация в `.claude_proxy_credentials`:**

```bash
# Telegram Bot интеграция
TELEGRAM_BOT_TOKEN=your_bot_token_here
TELEGRAM_CHAT_ID=your_chat_id_here
TELEGRAM_NOTIFY_ON_STOP=true
TELEGRAM_ALLOWED_USERS=123456789    # whitelist user_id через запятую
```

### Для команды: FastAPI + React

```
backend/
├── main.py             # FastAPI приложение
├── sessions.py         # Redis session manager
├── agents.py           # AgentDefinition конфигурации
├── guards.py           # can_use_tool security guards
└── requirements.txt

frontend/
├── src/
│   ├── App.tsx         # Главный компонент
│   ├── Chat.tsx        # Чат интерфейс
│   └── Terminal.tsx    # Терминальный вывод
└── package.json
```

### Схема данных сессии

```json
{
  "request_id": "uuid-...",
  "claude_session_id": "claude-...",
  "user_id": "telegram_user_id or web_user_id",
  "project_dir": "/path/to/project",
  "created_at": "2026-02-21T10:00:00Z",
  "last_active": "2026-02-21T10:30:00Z",
  "status": "done",
  "final_result": "..."
}
```

---

## 9. Пример интеграции в iclaude

### lib/telegram/bot.sh

```bash
start_telegram_bot() {
    local token="${TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${TELEGRAM_CHAT_ID:-}"

    if [[ -z "$token" ]]; then
        log_error "TELEGRAM_BOT_TOKEN не задан"
        return 1
    fi

    local bot_script="${SCRIPT_DIR}/lib/telegram/claude_bot.py"

    TELEGRAM_BOT_TOKEN="$token" \
    TELEGRAM_CHAT_ID="$chat_id" \
    PROJECT_DIR="${PWD}" \
    python3 "$bot_script" &

    echo $! > "${CLAUDE_DIR}/telegram-bot.pid"
    log_info "Telegram бот запущен (PID: $!)"
}

notify_telegram() {
    local message="$1"
    local token="${TELEGRAM_BOT_TOKEN:-}"
    local chat_id="${TELEGRAM_CHAT_ID:-}"

    if [[ -n "$token" && -n "$chat_id" ]]; then
        curl -s -X POST "https://api.telegram.org/bot${token}/sendMessage" \
            --data-urlencode "chat_id=${chat_id}" \
            --data-urlencode "text=${message}" \
            --data-urlencode "parse_mode=Markdown" > /dev/null
    fi
}
```

### Новые флаги iclaude.sh

```bash
--telegram-bot          # Запустить Telegram бот
--telegram-notify       # Отправить уведомление по завершении
--telegram-stop         # Остановить Telegram бот
--web-backend [PORT]    # Запустить FastAPI бэкенд (порт по умолчанию: 8765)
```

---

## Источники

- [Agent SDK Overview](https://platform.claude.com/docs/en/agent-sdk/overview) — обзор, примеры
- [Agent SDK Python Reference](https://platform.claude.com/docs/en/agent-sdk/python) — полный API reference
- [Agent SDK TypeScript Reference](https://platform.claude.com/docs/en/agent-sdk/typescript)
- [Headless Mode / CLI](https://code.claude.com/docs/en/headless) — claude -p флаги
- [claude-agent-sdk на PyPI](https://pypi.org/project/claude-agent-sdk/)
- [GitHub: anthropics/claude-agent-sdk-python](https://github.com/anthropics/claude-agent-sdk-python)
- [GitHub: anthropics/claude-agent-sdk-typescript](https://github.com/anthropics/claude-agent-sdk-typescript)
- [claude-code-telegram (RichardAtCT)](https://github.com/RichardAtCT/claude-code-telegram) — reference implementation
- [Claude Code FastAPI (E2B)](https://github.com/e2b-dev/claude-code-fastapi) — reference implementation
- [Microsoft Playwright MCP](https://github.com/microsoft/playwright-mcp)

---

*Последнее обновление: 2026-02-21 (после третьей верификации по официальной документации)*
