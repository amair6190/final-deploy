#!/usr/bin/env python
import os
import sys
import django

# Setup Django
os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'it_ticketing_system.settings')
sys.path.append('/home/amair/Desktop/curser with github/final WO Whatsapp/backup-3')
django.setup()

from tickets.forms import CustomerRegistrationForm
from tickets.models import CustomUser

def test_user_creation():
    print("=== TESTING USER CREATION ===")
    
    # Test data without email
    data = {
        'mobile': '9999999999',  # New unique mobile
        'first_name': 'Test',
        'last_name': 'Registration',
        'password1': 'TestPassword123!',
        'password2': 'TestPassword123!',
        # No email field
    }
    
    print("\n1. Testing user creation without email:")
    form = CustomerRegistrationForm(data=data)
    
    if form.is_valid():
        try:
            user = form.save()
            print(f"   ✅ User created successfully!")
            print(f"   ID: {user.id}")
            print(f"   Mobile: {user.mobile}")
            print(f"   Username: '{user.username}'")
            print(f"   Email: {user.email}")
            print(f"   Name: {user.get_full_name()}")
            
            # Clean up the test user
            user.delete()
            print("   Test user cleaned up.")
            
        except Exception as e:
            print(f"   ❌ Error creating user: {e}")
    else:
        print(f"   ❌ Form is not valid: {form.errors}")
    
    # Test data with email
    data_with_email = data.copy()
    data_with_email['mobile'] = '8888888888'  # Different mobile
    data_with_email['email'] = 'test@example.com'
    
    print("\n2. Testing user creation with email:")
    form = CustomerRegistrationForm(data=data_with_email)
    
    if form.is_valid():
        try:
            user = form.save()
            print(f"   ✅ User created successfully!")
            print(f"   ID: {user.id}")
            print(f"   Mobile: {user.mobile}")
            print(f"   Username: '{user.username}'")
            print(f"   Email: {user.email}")
            print(f"   Name: {user.get_full_name()}")
            
            # Clean up the test user
            user.delete()
            print("   Test user cleaned up.")
            
        except Exception as e:
            print(f"   ❌ Error creating user: {e}")
    else:
        print(f"   ❌ Form is not valid: {form.errors}")

if __name__ == "__main__":
    test_user_creation()
