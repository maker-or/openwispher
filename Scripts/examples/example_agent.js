const { execFileSync } = require("child_process");

function speak(text) {
  execFileSync("openwispher-speak", [text], { stdio: "inherit" });
}

speak("Hello from Node.js AI agent");
