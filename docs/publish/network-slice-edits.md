---
type: note
status: applied
tags: [store, privacy, network, ai]
project: spintax-studio
---

# Что меняется в опубликованном, когда появится сеть

> **ПЕРЕНЕСЕНО В ИСТОЧНИК 2026-08-09**, на срезе R1-1 — раньше, чем предполагал план.
> Гейт `http/the transport is not reachable from the window` покраснел, как только
> `gui/SpxLlm.pas` упомянул `SpxHttp`: продукт получил путь вызова, которому не хватает
> только кнопки. Соблазн был сузить проверку до «достижимо из формы» — этого не решает ни
> одно сканирование текста честно, и это было бы ослаблением проверки ради экономии.
>
> Ниже — то, что переехало, оставлено как запись о РЕШЕНИИ и его причинах. Не перенесено:
> счётчик ссылок (их по-прежнему две; третья приезжает с пунктом жалобы, R1-5) и
> декларация о данных при сертификации — она отвечается на форме при подаче.

Решение — [ADR 0012](../decisions/0012-the-network-slice-byo-key-over-winhttp.md). Здесь лежит
готовый текст: **буллет 17 листинга, три места в `docs/privacy.md` и декларация о данных при
сертификации.** Ничего из этого не публикуется сейчас.

**Почему текст лежит здесь, а не уже в `docs/privacy.md`.** Отгруженная сегодня сборка сети не
имеет — она честно не может сделать ни одного запроса, и `offline/… opens no socket` это
проверяет по каждому файлу. Политика, которая уже сейчас описывала бы сетевую функцию, была бы
ложной в другую сторону: не «умалчивает», а «обещает то, чего нет». Поэтому текст готов, а
въезжает он **тем же коммитом, который добавит файл в `NET_ALLOWED`** — то есть когда транспорт
действительно появится. Гейт и есть механизм: пока список пуст, любой `winhttp` в `uses` красит
сборку, и красной она останется, пока эти абзацы не переедут на место.

**И `winhttp` в списке запрещённых юнитов не было до 2026-08-09.** Проверка, написанная ради
офлайн-утверждения, не знала двух юнитов, к которым windows-приложение и тянется (`winhttp`,
`wininet`; оба в `winunits-base` и собраны под этот таргет). Транспорт, выбранный в ADR 0012,
проехал бы мимо неё на зелёной сборке. Исправлено при открытии среза — сверкой списка с тем, что
есть в тулчейне, а не доверием к его полноте.

---

## 1. Буллет 17 листинга

Сейчас (`docs/store-listing.md:104`):

> Offline by design: no account, cloud service, API key or telemetry, and no browser, Node.js,
> PHP or Python runtime

Становится:

> Offline by default: no account, no telemetry, and no browser, Node.js, PHP or Python runtime —
> the optional AI link uses your own key and your own provider

129 символов при пределе 200; список остаётся из двадцати (`scripts/check-listing-drafts.py`
считает и то и другое). **Утверждения про рантаймы остаются — они не перестают быть верными**, а
уходит ровно то, что перестаёт: «no cloud service, no API key» без оговорки.

Тринадцать локализованных черновиков в `marketing/store/` переписываются следом; проверка скажет,
если какой-то отстанет.

## 2. `docs/privacy.md` — три места

Правится **источник**, затем `scripts/`-путь переносит это в
[`privacy.html`](privacy.html) и [`privacy-partner-center.txt`](privacy-partner-center.txt).
Все три держит один гейт, и он же не даст обновить одну копию из трёх.

### 2.1. Сводка (сейчас строка 14)

> Spintax Studio is an offline desktop application. It does not collect, transmit or store any
> personal data.

Становится:

> Spintax Studio is an offline desktop application. It collects nothing about you: no account,
> no sign-in, no telemetry, no analytics. One feature is an exception and only when you switch
> it on — the AI draft can send the text you hand it to a model provider **you** choose and pay
> for, with **your** key. It is off until you turn it on, and this policy describes exactly what
> it sends.

### 2.2. «What we collect»

Абзац остаётся («Nothing»), к нему добавляется:

> Turning on the AI connection does not change this. Your key is stored on your own computer,
> encrypted for your Windows account, and goes nowhere except to the endpoint you pointed it at.
> We have no key of our own, no account for you, and no server in the middle: the request is
> made by this application, from your machine, on your provider's account. We never see it.

### 2.3. «What leaves your computer» (сейчас строка 25)

> Nothing. The application makes no network request of any kind — not at startup, not while you
> work, not on exit… and there is nothing in it that could make one.

Становится:

> **With the AI connection off — which is how the application is installed — nothing.** No part
> of it makes a network request: not at startup, not while you work, not on exit. The editor,
> validation, rendering, the variant generator, export and the built-in help have never needed
> one and still do not.
>
> **With it on, and only when you press the button that sends:** the prompt goes out. That is
> the brief you wrote, the variable names you listed, and — when you ask for a repair — the
> draft and the diagnostics the engine found in it. It goes to the endpoint you configured, with
> your key, on your account. Nothing else is added to it: no identifier, no document you did not
> send, no record kept here of what you sent.
>
> **And if the endpoint you configure is a local one** — a model running on your own machine, at
> an address like `http://localhost:11434` — then nothing leaves the computer at all. That is a
> different thing from a cloud provider, and this policy is not going to blur them: with a local
> model the whole loop, prompt included, stays where your documents are.
>
> What the provider does with what you send is theirs to state, not ours. Their policy applies
> to that exchange, and we are not a party to it.

**Абзац про две ссылки остаётся без изменений.** Ссылка — не сетевой запрос: адрес передаётся
оболочке, а ходит браузер пользователя. Эта разница уже была потеряна один раз при редактуре
(2026-08-08) и восстановлена по замечанию владельца — не терять её снова.

## 3. Декларация о данных при сертификации

**Ответ прошлой подачи не переносится.** Приложение начинает передавать введённый пользователем
текст третьей стороне, которую он выбрал сам, — это отдельная строка формы, а не следствие
правки политики. Ответить заново, прочитав вопрос на форме, а не по памяти: точную формулировку
Partner Center здесь не воспроизводим, потому что она меняется, а неверно процитированный вопрос
хуже отсутствующего.

## 4. Порядок

1. Код среза (`N1`–`N6`) и **эти правки** — один коммит: файл попадает в `NET_ALLOWED`, абзацы
   переезжают в `docs/privacy.md`, три копии расходятся из источника.
2. WACK и `docs/release-validation.md` снимаются заново (`N7`) — этот кандидат впервые делает
   исходящие соединения, и прошлый прогон про него ничего не говорит.
3. Публикация — по явной команде владельца, и правки листинга едут тем же визитом в Partner
   Center, что и остальные накопленные (`store-listing-edits.md`).
