#!/bin/bash
set -e

openwispher-speak "CLI test message"
openwispher-speak "Groq voice test" --provider groq --voice alloy
openwispher-speak "Deepgram voice test" --provider deepgram --voice aura-asteria
openwispher-speak "ElevenLabs voice test" --provider elevenlabs --voice 21m00Tcm4TlvDq8ikWAM
openwispher-speak "OpenAI voice test" --provider openai --voice nova
