import subprocess

def speak(text: str) -> None:
    subprocess.run(["openwhisper-speak", text], check=True)

if __name__ == "__main__":
    speak("Hello from Python AI agent")
