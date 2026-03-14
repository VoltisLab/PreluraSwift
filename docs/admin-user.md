# Admin user for Admin Dashboard

The **Admin Dashboard** in the app (Menu → Admin Dashboard) is shown for any user who is **staff or superuser** (backend `is_staff=True` or `is_superuser=True`).

## Make Testuser the superuser (backend)

**Option A – from this repo (Prelura-swift):**  
Run the script where the backend has env (e.g. on the deployment server, or locally after adding `.env` to prelura-app):

```bash
cd /path/to/Prelura-swift
export PRELURA_APP=/path/to/prelura-app   # or your backend repo path
./scripts/make-testuser-superuser.sh
```

**Option B – from the backend repo:**  
From the **prelura-app** root, with environment loaded (e.g. `.env` present or on server):

```bash
cd /path/to/prelura-app
./venv/bin/python manage.py shell -c "
from accounts.models import User
u = User.objects.filter(username__iexact='Testuser').first()
if u:
    u.is_superuser = True
    u.is_staff = True
    u.save()
    print('Testuser is now superuser and staff.')
else:
    print('User Testuser not found.')
"
```

After this, logging in as **Testuser** will show the Admin Dashboard in the menu and allow use of “Delete all orders”, “Delete all messages”, and “Delete all notifications”.

## Create the Admin user (backend)

Create the user in the **prelura-app** backend repo (this app does not modify the backend). From the backend repo root:

```bash
cd /path/to/prelura-app
python manage.py shell -c "
from accounts.models import User
if not User.objects.filter(username__iexact='Admin').exists():
    User.objects.create_superuser('Admin', 'admin@prelura.example.com', 'Password123!!!')
    print('Created user Admin')
else:
    print('User Admin already exists')
"
```

- **Username:** Admin  
- **Password:** Password123!!!  
- Superuser has `is_staff=True`, which is required for the “Delete all conversations” (and linked orders) API.

To set the password on an existing user:

```bash
python manage.py shell -c "
from accounts.models import User
u = User.objects.get(username__iexact='Admin')
u.set_password('Password123!!!')
u.save()
print('Password updated')
"
```
