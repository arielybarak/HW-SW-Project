# 1) Free port 8000 and (re)start local server in background
fuser -k 8000/tcp 2>/dev/null || true
nohup python3 -m http.server --directory /root 8000 --bind 127.0.0.1 >/dev/null 2>&1 &
# 2) Create an SSH key for localhost.run
mkdir -p ~/.ssh
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
# 3) Open a public tunnel (keep this running; it will print a URL)
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 -R 80:localhost:8000 ssh.localhost.run
