FROM oc-sandbox-base:latest
RUN bun install -g opencode-ai \
    && mkdir -p /home/agent/.config/opencode/agents

RUN opencode plugin opencode-pty@latest -g
RUN opencode plugin @franlol/opencode-md-table-formatter@latest -g
RUN opencode plugin opencode-conductor-plugin@latest -g
RUN npm install -g opencode-qwencode-auth && \
    cd /usr/local/share/npm-global/lib/node_modules/opencode-qwencode-auth && \
    npm run build
RUN opencode plugin @tarquinen/opencode-dcp@latest -g
RUN bunx get-shit-done-cc --opencode --sdk --global
#RUN opencode plugin oh-my-openagent@latest -g
RUN opencode plugin opencode-websearch-cited@latest -g

COPY --chown=agent:agent .opencode/* /home/agent/.config/opencode
COPY --chown=agent:agent agents/* /home/agent/.config/opencode/agents/

VOLUME ["/home/agent/.config/opencode", "/home/agent/.local/share/opencode"]
ENV PATH="/home/agent/.config/opencode/get-shit-done/bin:$PATH"
CMD ["opencode"]
