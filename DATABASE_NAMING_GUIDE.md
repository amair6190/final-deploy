## 🗄️ Database Naming Rules for PostgreSQL

### ✅ **Valid Database Names:**
- `solvit_ticketing` ✓
- `ticketing_system` ✓
- `my_database` ✓
- `db_001` ✓
- `user_management` ✓

### ❌ **Invalid Database Names:**
- `solvit-ticketing` ❌ (contains hyphen)
- `my database` ❌ (contains space)
- `123database` ❌ (starts with number)
- `solvit.ticketing` ❌ (contains dot)
- `database-name` ❌ (contains hyphen)

### 📋 **Rules:**
1. **Start with:** Letter (a-z, A-Z) or underscore (_)
2. **Can contain:** Letters, numbers (0-9), underscores (_)
3. **Cannot contain:** Hyphens (-), spaces, dots (.), special characters
4. **Case sensitive:** `MyDatabase` and `mydatabase` are different

### 💡 **Recommendations:**
- Use descriptive names: `ticketing_system`, `user_database`
- Keep it simple: shorter names are easier to manage
- Use underscores for separation: `my_app_db`
- Stick to lowercase for consistency: `solvit_ticketing`

### 🔧 **If you already used a hyphen:**
Convert hyphens to underscores:
- `solvit-ticket` → `solvit_ticket`
- `my-app-db` → `my_app_db`
- `user-management` → `user_management`
