# Provider Model Verification

This note records the provider-default review performed on 2026-09-05. The app keeps provider model identifiers user-editable because availability depends on the customer account and endpoint, but its first-party defaults should remain current stable identifiers.

| Provider | Configured default | Verification |
| --- | --- | --- |
| OpenAI-compatible | `gpt-5.6-luna` | OpenAI documents `gpt-5.6-luna` as GPT-5.6 Luna, its cost-sensitive, high-volume model. It is suitable as a lightweight assistant default. [1] |
| Google Gemini | `gemini-3.8-flash` | Google lists `gemini-3.8-flash` as a stable Gemini API endpoint. [2] |
| Anthropic | `claude-sonnet-5` | Anthropic lists `claude-sonnet-5` as the Claude API ID for Claude Sonnet 5. [3] |

The connection test is deliberately a minimal chat completion request; it validates the configured endpoint, model, and API key together rather than relying on a vendor-specific model-list endpoint. A custom OpenAI-compatible endpoint may expose a different model catalog, so its model field remains editable.

## References

[1]: https://developers.openai.com/api/docs/models
[2]: https://ai.google.dev/gemini-api/docs/models
[3]: https://platform.claude.com/docs/en/models/overview
