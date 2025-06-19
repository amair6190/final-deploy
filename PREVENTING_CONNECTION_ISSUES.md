# Preventing Connection Issues in SolvIT Ticketing System

## Common Connection Issue: ERR_CONNECTION_REFUSED

One of the most common issues when deploying the SolvIT Ticketing system is getting an **ERR_CONNECTION_REFUSED** error when trying to access the application from a machine other than the server itself.

## Root Cause

The primary cause of this issue is that Gunicorn (the WSGI server) is sometimes configured to listen only on the localhost interface (`127.0.0.1`) rather than on all network interfaces (`0.0.0.0`).

When Gunicorn listens only on localhost:
- It's only accessible from the same machine
- External connections are refused, causing the ERR_CONNECTION_REFUSED error
- The server is effectively isolated, even though the port is open in the firewall

## How We've Fixed This Issue

We've implemented several measures to ensure this issue doesn't happen again:

1. **Updated Deployment Scripts**: All deployment scripts now use `0.0.0.0:8001` instead of `127.0.0.1:8001` for Gunicorn binding.

2. **Auto-Fix in Verification Script**: The `post_deploy_verify.sh` script now automatically checks and fixes the Gunicorn binding without requiring user confirmation.

3. **Dedicated Fix Script**: A new script called `fix_gunicorn_binding.sh` has been created that can be run on any existing deployment to fix this issue.

## How to Verify Proper Configuration

You can check if Gunicorn is properly configured by running:

```bash
sudo lsof -i :8001
```

The output should show something like:
```
COMMAND     PID   USER   FD   TYPE DEVICE SIZE/OFF NODE NAME
gunicorn 160605 solvit    5u  IPv4 858143      0t0  TCP *:8001 (LISTEN)
```

The `*:8001` indicates that Gunicorn is listening on all interfaces. If you see `127.0.0.1:8001` instead, you need to run the fix script:

```bash
sudo ./fix_gunicorn_binding.sh
```

## Testing External Access

After ensuring Gunicorn is listening on all interfaces, test external access:

1. From the server itself:
```bash
curl -I http://127.0.0.1:8001
```

2. From another machine on the network:
```bash
curl -I http://SERVER_IP:8001
```

Both should return an HTTP 200 OK response.

## Related Documentation

- For Nginx Proxy Manager setup: `NPM_VISUAL_GUIDE.md`
- For troubleshooting other issues: `DEPLOYMENT_TROUBLESHOOTING.md`
- For connection verification: `CONNECTION_ISSUE_FIXED.md`
