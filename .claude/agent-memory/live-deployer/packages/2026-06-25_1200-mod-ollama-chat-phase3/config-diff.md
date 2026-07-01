# Config diff: live vs PTR — mod_ollama_chat.conf

**Live file (read-only):** `env/dist/etc/modules/mod_ollama_chat.conf`
**PTR file (reference):** `env/dist/etc-ptr/modules/mod_ollama_chat.conf`

Apply these changes manually to `env/dist/etc/modules/mod_ollama_chat.conf`.
No other keys need to change — the large template strings (RandomChatter, EventChatter, etc.)
are already identical between live and PTR.

---

## Changes required

### 1. Model (CHANGE)

```
# FROM:
OllamaChat.Model = qwen2.5:14b

# TO:
OllamaChat.Model = gemma4:12b
```

### 2. NumPredict (CHANGE)

```
# FROM:
OllamaChat.NumPredict = 60

# TO:
OllamaChat.NumPredict = 80
```

### 3. Temperature (CHANGE)

```
# FROM:
OllamaChat.Temperature = 0.4

# TO:
OllamaChat.Temperature = 0.3
```

### 4. TopP (CHANGE)

```
# FROM:
OllamaChat.TopP = 0.95

# TO:
OllamaChat.TopP = 0.9
```

### 5. RepeatPenalty (CHANGE)

```
# FROM:
OllamaChat.RepeatPenalty = 1.1

# TO:
OllamaChat.RepeatPenalty = 1.15
```

### 6. NumCtx (CHANGE)

```
# FROM:
OllamaChat.NumCtx = 0

# TO:
OllamaChat.NumCtx = 8192
```

### 7. MaxConcurrentQueries (CHANGE)

```
# FROM:
OllamaChat.MaxConcurrentQueries = 3

# TO:
OllamaChat.MaxConcurrentQueries = 2
```

### 8. SystemPrompt (CHANGE — minor text fix, adds "Используй только обычный дефис")

```
# FROM:
OllamaChat.SystemPrompt = "Ты — игрок World of Warcraft эпохи Wrath of the Lich King. Всегда отвечай ТОЛЬКО на русском языке кириллицей. Используй живой разговорный русский, игровой сленг WoW (дамагер, хил, танк, фарм, гринд, лут, рейд, инст, данж, абилка, прокнуло, вайп, пул, агр, баф, дебаф, манна, ресы, откат). Никогда не переводи дословно с английского — говори так, как реально общаются русскоязычные игроки WoW."

# TO:
OllamaChat.SystemPrompt = "Ты - игрок World of Warcraft эпохи Wrath of the Lich King. Всегда отвечай ТОЛЬКО на русском языке кириллицей. Используй живой разговорный русский, игровой сленг WoW (дамагер, хил, танк, фарм, гринд, лут, рейд, инст, данж, абилка, прокнуло, вайп, пул, агр, баф, дебаф, манна, ресы, откат). Никогда не переводи дословно с английского - говори так, как реально общаются русскоязычные игроки WoW. Пиши простым текстом для игрового чата: без markdown, без звёздочек, без действий в звёздочках, без эмодзи. Используй только обычный дефис (-), не длинное тире. Отвечай кратко, 1-2 предложения."
```

### 9. NEW BLOCK — Custom features (Phase 1, 2, 3)

Insert this block immediately AFTER the line `OllamaChat.EnableRPPersonalities = 1`
and BEFORE the line `# OllamaChat.DefaultPersonalityPrompt` (which in the live file comes
directly after the RP personalities section header).

```
# === Custom OllamaChat features (enabled for live) ===
# Phase 1: named characters
OllamaChat.EnableNamedCharacters = 1
OllamaChat.NamedCharactersFile = /azerothcore/modules/mod-ollama-chat/data/characters.json
# Phase 2 + Delta B: world-news daily topics (Deutsche Welle)
OllamaChat.EnableNewsFeed = 1
OllamaChat.NewsFeedUrl = https://rss.dw.com/rdf/rss-ru-all
OllamaChat.NewsFeedRefreshInterval = 30
OllamaChat.NewsFeedMaxItems = 20
OllamaChat.NewsFeedDailyTopicCount = 5
OllamaChat.NewsFeedCommentChance = 10
OllamaChat.NewsFeedCommentTemplate = Слышал новость: {headline}. Что думаешь об этом?
OllamaChat.NewsFeedBlockedKeywords =
# Phase 3: long-term per-player memory
OllamaChat.EnableLongTermMemory = 1
OllamaChat.MemorySummaryEveryNMessages = 10
OllamaChat.MemorySummaryModel =
OllamaChat.MemorySummaryThinkMode = 1
OllamaChat.MemorySummaryNumPredict = 1024
OllamaChat.MemorySummaryPrompt = Ниже история общения между {bot_name} и игроком {player_name}. Кратко, в 2-3 предложениях на русском, опиши что {bot_name} помнит об этом игроке: факты, отношения, прошлые события. Выведи ТОЛЬКО текст памяти, без кавычек и пояснений. {history}
OllamaChat.BotMemoryPromptTemplate = Что ты помнишь об этом игроке: {bot_memory}
# Delta A: extended daily journal
OllamaChat.EnableExtendedMemory = 1
OllamaChat.ExtendedMemoryBots = 568,566
OllamaChat.ExtendedMemoryGuildName =
OllamaChat.ExtendedMemoryGuildId = 24
OllamaChat.ExtendedMemoryRetentionDays = 7
OllamaChat.ExtendedMemoryMaxEntriesPerDay = 20
OllamaChat.ExtendedMemoryDaysInPrompt = 2
OllamaChat.ExtendedMemorySaveInterval = 10
OllamaChat.BotJournalPromptTemplate = Твой дневник за последние дни: {journal_digest}
# === end custom features ===
```

### 10. ChatPromptTemplate (CHANGE — adds {bot_memory} {bot_journal} placeholders)

```
# FROM:
OllamaChat.ChatPromptTemplate = "Ты — игрок WoW эпохи Wrath, знаком с Ваниллой и ТБС. Имя: {bot_name}, {bot_level} уровень {bot_class}. ОБЯЗАТЕЛЬНО ОТВЕЧАЙ В СООТВЕТСТВИИ СО СВОЕЙ ЛИЧНОСТЬЮ: {bot_personality_name}: {bot_personality}. {sentiment_info} {chat_history} Игрок {player_name} ({player_level} уровень {player_class}) написал: '{player_message}'. {extra_info} Ответь естественно, до 15 слов, на русском. Используй живой WoW-сленг. Будь резким если провоцируют. Будь точным если спрашивают дорогу. Не противоречь своему классу, расе или локации. Не будь рассказчиком — отвечай как игрок."

# TO:
OllamaChat.ChatPromptTemplate = "Ты — игрок WoW эпохи Wrath, знаком с Ваниллой и ТБС. Имя: {bot_name}, {bot_level} уровень {bot_class}. ОБЯЗАТЕЛЬНО ОТВЕЧАЙ В СООТВЕТСТВИИ СО СВОЕЙ ЛИЧНОСТЬЮ: {bot_personality_name}: {bot_personality}. {sentiment_info} {bot_memory} {bot_journal} {chat_history} Игрок {player_name} ({player_level} уровень {player_class}) написал: '{player_message}'. {extra_info} Ответь естественно, до 15 слов, на русском. Используй живой WoW-сленг. Будь резким если провоцируют. Будь точным если спрашивают дорогу. Не противоречь своему классу, расе или локации. Не будь рассказчиком — отвечай как игрок."
```

The critical change is adding `{bot_memory} {bot_journal}` after `{sentiment_info}`.

---

## Summary of what stays unchanged

All of the following sections are **identical** between live and PTR and require no editing:
- All chance values (PlayerReplyChance.*, BotReplyChance.*)
- BlacklistCommands
- All distance settings
- EnableTypingSimulation / typing delays
- EnableRPPersonalities = 1
- DefaultPersonalityPrompt
- All EnableChatHistory / history templates
- EnableSentimentTracking (0 in both)
- All sentiment templates
- ChatExtraInfoTemplate
- All Env* templates (creature, gameobject, items, spells, etc.)
- All EventType* and EventType*_Chance values
- All Guild* templates and chances
- RAG section (disabled in both)
