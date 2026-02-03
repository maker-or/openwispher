#!/bin/bash
set -e

openwhisper-speak "CLI test message"
openwhisper-speak "Groq voice test" --provider groq --voice alloy
openwhisper-speak "Deepgram voice test" --provider deepgram --voice aura-asteria
openwhisper-speak "ElevenLabs voice test" --provider elevenlabs --voice 21m00Tcm4TlvDq8ikWAM
openwhisper-speak "OpenAI voice test" --provider openai --voice nova
