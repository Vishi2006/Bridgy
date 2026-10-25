# #0002 AI Agents hit OpenRouter credit limit because a stale shell-exported OPENROUTER_API_KEY overrode server/.env

- 2026-10-24T23:27:00Z `issue`: AI Agents hit OpenRouter credit limit because a stale shell-exported OPENROUTER_API_KEY overrode server/.env [server/config.js]
- 2026-10-24T23:27:02Z `fix`: server/config.js reads the key from server/.env only; model fixed to deepseek/deepseek-v4.1-flash-1017. Stale-env smoke test returned 200, npm test 6/6, flutter test 19/19. [server/config.js]
