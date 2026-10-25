# #0001 PolicyController.save inserts agent_session_key, but server/schema.sql omits that column, so Supabase save fails when no wallet row exists.

- 2026-10-24T22:30:42Z `issue`: PolicyController.save inserts agent_session_key, but server/schema.sql omits that column, so Supabase save fails when no wallet row exists. [lib/state/policy_controller.dart]
- 2026-10-25T01:10:03Z `fix`: Removed agent_session_key from the wallets insert in PolicyController.save and Backend pay-agent upsert. Policy save now reports backend success even when the Supabase mirror fails. flutter test 19/19. [lib/state/policy_controller.dart]
