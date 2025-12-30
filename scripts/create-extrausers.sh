#!/bin/bash
# Generate extrausers assertion for KarmaOS default admin user
# Username: admin
# Password: karmaos

cat > extrausers.json << 'EOF'
{
  "type": "system-user",
  "authority-id": "N8QOMWILcV2etddoinjqxG62LwIHiK92",
  "brand-id": "N8QOMWILcV2etddoinjqxG62LwIHiK92",
  "email": "admin@karmaos.local",
  "series": ["16"],
  "models": ["karmaos-pc-amd64"],
  "name": "KarmaOS Default Admin",
  "username": "admin",
  "password": "$6$rounds=4096$saltsaltsalt$3FH.dTLBrZ7E5mVYFHKqXqLQVxjVKJwKqGjXqrIbZd4rqRvKjN8pQqPqMqOqLqKqJqIqHqGqFqEqDqCqBqA",
  "since": "2025-12-29T00:00:00Z",
  "until": "2035-12-29T00:00:00Z"
}
EOF

echo "Assertion JSON created. Sign with:"
echo "snap sign -k karmaos extrausers.json > extrausers.assert"
