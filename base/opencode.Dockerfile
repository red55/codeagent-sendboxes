FROM oc-sandbox-base:latest
RUN bun install -g opencode-ai@1.14.19 \
    && mkdir -p /home/agent/.config/opencode/agents


COPY --chown=agent:agent .opencode/* /home/agent/.config/opencode
COPY --chown=agent:agent agents/* /home/agent/.config/opencode/agents/

RUN opencode plugin opencode-pty@0.3.4 -g
RUN opencode plugin @franlol/opencode-md-table-formatter@0.0.6 -g
RUN opencode plugin opencode-conductor-plugin@1.32.0 -g
RUN npm install -g opencode-qwencode-auth@1.3.0 && \
    cd /usr/local/share/npm-global/lib/node_modules/opencode-qwencode-auth && \
    npm run build
RUN opencode plugin @tarquinen/opencode-dcp@3.1.9 -g
RUN bunx get-shit-done-cc@1.38.1 --opencode --sdk --global
RUN opencode plugin opencode-websearch-cited@1.2.0 -g


VOLUME ["/home/agent/.config/opencode", "/home/agent/.local/share/opencode"]
ENV PATH="/home/agent/.config/opencode/get-shit-done/bin:$PATH"
CMD ["opencode"]
