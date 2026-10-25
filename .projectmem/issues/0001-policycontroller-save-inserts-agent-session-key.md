# #0001 PolicyController.save inserts agent_session_key, but server/schema.sql omits that column, so Supabase save fails when no wallet row exists.

- 2026-10-24T22:30:42Z `issue`: PolicyController.save inserts agent_session_key, but server/schema.sql omits that column, so Supabase save fails when no wallet row exists. [lib/state/policy_controller.dart]
