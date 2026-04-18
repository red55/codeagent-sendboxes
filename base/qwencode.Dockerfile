FROM qc-sandbox-base:latest
RUN bun install -g @qwen-code/qwen-code@latest
RUN bunx get-shit-done-cc --qwencode --global --sdk