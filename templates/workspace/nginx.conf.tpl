# Workspace Nginx: ws-__WS_NAME__
# Per-project stubs live inside the workspace volume:
#   /workspace/nginx-stubs/__WS_NAME__/*.conf

server {
  listen 80 default_server;
  server_name _;
  return 404;
}

include /workspace/nginx-stubs/__WS_NAME__/*.conf;