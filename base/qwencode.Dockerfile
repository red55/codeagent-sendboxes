FROM qc-sandbox-base:latest
RUN bun install -g @qwen-code/qwen-code@0.14.5
RUN bunx get-shit-done-cc@1.38.1 --qwencode --global --sdk
